/* eslint-disable max-len, require-jsdoc, @typescript-eslint/no-explicit-any, object-curly-spacing */
import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {onInit} from "firebase-functions/v2/core";
import {setGlobalOptions} from "firebase-functions/v2/options";
import * as logger from "firebase-functions/logger";
// admin SDKのインポート
import * as admin from "firebase-admin";
// 追加: FieldValue を明示 import（ランタイムで未定義を防ぐ）
import { FieldValue } from "firebase-admin/firestore";

// グローバルオプション設定
setGlobalOptions({region: "us-central1"});

// アプリ初期化状態フラグ
let appInitialized = false;

// デプロイ中は初期化を走らせない
function ensureApp() {
  if (!appInitialized) {
    admin.initializeApp();
    appInitialized = true;
  }
}

// 確実にランタイム時のみ実行される初期化
onInit(() => {
  ensureApp();
  logger.info("Admin initialized in onInit");
});

// 定数定義とヘルパー関数
const typeWeakness: Record<string, string> = {
  IT: "語学",
  語学: "ビジネス",
  ビジネス: "IT",
};

// finalPower関数の復元
function finalPower(base: number, myType: string, oppType: string): { power: number; advantaged: boolean } {
  const advantaged = typeWeakness[myType] === oppType;
  return {power: advantaged ? base * 2 : base, advantaged};
}

// 関数のみをexport（初期化を含まない）
export const helloWorld = onRequest(
  {region: "us-central1"},
  (req, res) => {
    ensureApp();
    logger.info("helloWorld called", {method: req.method});
    res.status(200).send("Hello from Firebase!");
  }
);

// Firestore書き込み（認証必須 / Web対応のCORS有効）
export const testWriteFirestore = onCall(
  {cors: true, region: "us-central1", minInstances: 0},
  async (request) => {
    ensureApp();
    try {
      // 1) 認証チェック
      if (!request.auth) throw new HttpsError("unauthenticated", "認証が必要です");

      // 2) 入力の取り出し＋最小バリデーション
      const raw = request.data?.text;
      const text = typeof raw === "string" && raw.trim().length > 0 ? raw.trim() : "テストデータ";

      // 3) 書き込み先を作成
      const docRef = admin.firestore().collection("functions_test").doc();

      // 4) Firestoreへ書き込み（サーバー時刻を付与）
      await docRef.set({
        text,
        userId: request.auth.uid,
        createdAt: FieldValue.serverTimestamp(),
      });

      // 5) ログ出力（監査/デバッグ）
      logger.info("testWriteFirestore ok", {uid: request.auth.uid, docId: docRef.id});

      // 6) 直列化可能なJSONを返す
      return {success: true, documentId: docRef.id};
    } catch (err: any) {
      logger.error("testWriteFirestore error", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", err?.message ?? "internal");
    }
  }
);

export const endTurn = onCall(
  {cors: true, region: "us-central1", minInstances: 0},
  async (request) => {
    ensureApp();
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "認証が必要です");
      const uid = request.auth.uid;

      const {roomId, clientActionId, expectVersion} = request.data ?? {};
      if (typeof roomId !== "string" || roomId.trim().length === 0) {
        throw new HttpsError("invalid-argument", "roomId 必須");
      }
      if (typeof clientActionId !== "string" || clientActionId.trim().length === 0) {
        throw new HttpsError("invalid-argument", "clientActionId 必須");
      }

      const roomRef = admin.firestore().collection("rooms").doc(roomId);

      const result = await admin.firestore().runTransaction(async (tx) => {
        const snap = await tx.get(roomRef);
        if (!snap.exists) throw new HttpsError("not-found", "room が存在しません");
        const room = snap.data() as any;

        const p1 = room.player1_id as string | undefined;
        const p2 = room.player2_id as string | undefined;
        const players = [p1, p2].filter(Boolean) as string[];

        if (!players.includes(uid)) throw new HttpsError("permission-denied", "参加者ではありません");

        const gs = (room.game_state ?? {}) as any;
        const v = typeof room.version === "number" ? room.version : 0;

        // 追加: すでに終了済みの部屋は確定処理をスキップ
        if (room.room_status === "finished") {
          return {dedup: true, version: v, summary: {message: "room already finished"}};
        }

        if (expectVersion != null && expectVersion !== v) {
          throw new HttpsError("aborted", "version mismatch");
        }

        const processed: string[] = Array.isArray(room.processedActionIds) ? room.processedActionIds : [];
        if (processed.includes(clientActionId)) {
          return {dedup: true, version: v, summary: {message: "already processed"}};
        }

        const p1CardId = gs.player1_card as number | null | undefined;
        const p2CardId = gs.player2_card as number | null | undefined;
        if (!p1CardId || !p2CardId) {
          throw new HttpsError("failed-precondition", "両プレイヤーのカードが未選択です");
        }

        // cards コレクションからカード情報を取得（id フィールドで検索）
        const cardsCol = admin.firestore().collection("cards");
        const q1 = cardsCol.where("id", "==", p1CardId).limit(1);
        const q2 = cardsCol.where("id", "==", p2CardId).limit(1);
        const [p1Snap, p2Snap] = await Promise.all([tx.get(q1), tx.get(q2)]);
        if (p1Snap.empty || p2Snap.empty) throw new HttpsError("not-found", "カード情報が見つかりません");

        const c1 = p1Snap.docs[0].data() as any;
        const c2 = p2Snap.docs[0].data() as any;

        const p1Base = (c1.power as number) ?? 0;
        const p2Base = (c2.power as number) ?? 0;
        const p1Type = (c1.type as string) ?? "";
        const p2Type = (c2.type as string) ?? "";

        const p1Final = finalPower(p1Base, p1Type, p2Type);
        const p2Final = finalPower(p2Base, p2Type, p1Type);

        // 勝敗と差分
        let p1PointDelta = 0;
        let p2PointDelta = 0;
        let p1OmpDelta = 0;
        let p2OmpDelta = 0;
        let turnResult: "p1" | "p2" | "draw" = "draw";

        if (p1Final.power > p2Final.power) {
          p1PointDelta = 1;
          p2OmpDelta = p1Final.power - p2Final.power;
          turnResult = "p1";
        } else if (p1Final.power < p2Final.power) {
          p2PointDelta = 1;
          p1OmpDelta = p2Final.power - p1Final.power;
          turnResult = "p2";
        }

        // 現在値
        const curP1Pts = (gs.player1_point as number) ?? 0;
        const curP2Pts = (gs.player2_point as number) ?? 0;
        const curP1Omp = (gs.player1_over_mount as number) ?? 0;
        const curP2Omp = (gs.player2_over_mount as number) ?? 0;
        const curTurn = (gs.turn as number) ?? 1;

        // 新しい値
        const newP1Pts = curP1Pts + p1PointDelta;
        const newP2Pts = curP2Pts + p2PointDelta;
        const newP1Omp = curP1Omp + p1OmpDelta;
        const newP2Omp = curP2Omp + p2OmpDelta;

        const finished =
          newP1Pts >= 3 || newP2Pts >= 3 || newP1Omp > 100 || newP2Omp > 100;
        const winnerId = finished ?
          newP1Pts >= 3 || newP2Omp > 100 ?
            p1 ?? null :
            p2 ?? null :
          null;

        // 更新内容（game_stateとメタ）
        const update: any = {
          version: v + 1,
          processedActionIds: [...processed.slice(-49), clientActionId],
          updatedAt: FieldValue.serverTimestamp(),
          game_state: {
            ...gs,
            player1_point: newP1Pts,
            player2_point: newP2Pts,
            player1_over_mount: newP1Omp,
            player2_over_mount: newP2Omp,
            turn: curTurn + 1,
            player1_card: null,
            player2_card: null,
          },
        };

        if (finished) {
          update.room_status = "finished";
          update.winner_id = winnerId;
          update.finished_at = FieldValue.serverTimestamp();
        }

        tx.set(roomRef, update, {merge: true});

        // 監査ログ
        const logRef = roomRef.collection("actions").doc(clientActionId);
        tx.set(logRef, {
          type: "endTurn",
          uid,
          createdAt: FieldValue.serverTimestamp(),
          p1CardId,
          p2CardId,
          p1Base,
          p2Base,
          p1Final: p1Final.power,
          p2Final: p2Final.power,
          turnFrom: curTurn,
          turnTo: curTurn + 1,
          result: turnResult,
          version: v + 1,
        });

        return {
          dedup: false,
          version: v + 1,
          finished,
          winnerId,
          summary: {
            result: turnResult,
            p1Final: p1Final.power,
            p2Final: p2Final.power,
            p1Adv: p1Final.advantaged,
            p2Adv: p2Final.advantaged,
            newP1Pts,
            newP2Pts,
            newP1Omp,
            newP2Omp,
            nextTurn: curTurn + 1,
          },
        };
      });

      logger.info("endTurn ok", {roomId, uid, result});
      return {ok: true, ...result};
    } catch (err: any) {
      logger.error("endTurn error", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", err?.message ?? "internal");
    }
  }
);

export const createOrJoinRoom = onCall(
  {cors: true, region: "us-central1", minInstances: 0},
  async (request) => {
    ensureApp();
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "認証が必要です");
      const uid = request.auth.uid;
      const roomId = typeof request.data?.roomId === "string" ? request.data.roomId.trim() : "";

      const db = admin.firestore();
      const now = FieldValue.serverTimestamp();

      if (!roomId) {
        // サーバー側マッチング:
        // 1) 待機中（player2_id=null && room_status='waiting'）かつ自分が作成していない部屋を1件取得
        const q = await db
          .collection("rooms")
          .where("room_status", "==", "waiting")
          .where("player2_id", "==", null)
          .limit(10)
          .get();

        // 自分が作った部屋以外を優先
        const candidate = q.docs.find((d) => {
          const r = d.data() as any;
          return r.player1_id !== uid;
        });

        if (candidate) {
          // トランザクションで player2 として参加＆match 化
          const ref = candidate.ref;
          const res = await db.runTransaction(async (tx) => {
            const snap = await tx.get(ref);
            if (!snap.exists) throw new HttpsError("not-found", "room が存在しません");
            const r = snap.data() as any;
            if (r.player2_id) throw new HttpsError("failed-precondition", "すでに満席です");
            if (r.room_status === "finished") throw new HttpsError("failed-precondition", "終了済みの部屋です");

            tx.set(ref, {
              player2_id: uid,
              room_status: "match",
              updatedAt: now,
              version: typeof r.version === "number" ? r.version : 0,
              processedActionIds: Array.isArray(r.processedActionIds) ? r.processedActionIds : [],
            }, { merge: true });

            return { ok: true, roomId: ref.id, joinedAs: "player2" as const };
          });
          return res;
        }

        // 2) 待機ルームがなければ新規作成（player1 として waiting）
        const ref = db.collection("rooms").doc();
        await ref.set({
          player1_id: uid,
          player2_id: null,
          room_status: "waiting",
          version: 0,
          processedActionIds: [],
          created_at: now,
          updatedAt: now,
          game_state: {
            player1_point: 0,
            player2_point: 0,
            player1_over_mount: 0,
            player2_over_mount: 0,
            turn: 1,
            player1_card: null,
            player2_card: null,
          },
        });
        return { ok: true, roomId: ref.id, joinedAs: "player1" as const };
      } else {
        // 明示された roomId に参加/作成（既存仕様を維持）
        const ref = db.collection("rooms").doc(roomId);
        const res = await db.runTransaction(async (tx) => {
          const snap = await tx.get(ref);
          if (!snap.exists) throw new HttpsError("not-found", "room が存在しません");
          const r = snap.data() as any;

          if (r.player1_id === uid || r.player2_id === uid) {
            return { ok: true, roomId, joinedAs: r.player1_id === uid ? "player1" : "player2" };
          }
          if (!r.player2_id && r.room_status !== "finished") {
            tx.update(ref, { player2_id: uid, room_status: "match", updatedAt: now });
            return { ok: true, roomId, joinedAs: "player2" };
          }
          throw new HttpsError("failed-precondition", "満席です");
        });
        return res;
      }
    } catch (e: any) {
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", e?.message ?? "internal");
    }
  }
);

// 追加: 退室処理（待機中は削除、対戦中は離脱状態に更新）
export const leaveRoom = onCall(
  { cors: true, region: "us-central1", minInstances: 0 },
  async (request) => {
    ensureApp();
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "認証が必要です");
      const uid = request.auth.uid;
      const { roomId } = request.data ?? {};
      if (typeof roomId !== "string" || !roomId.trim()) {
        throw new HttpsError("invalid-argument", "roomId 必須");
      }

      const db = admin.firestore();
      const ref = db.collection("rooms").doc(roomId);

      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) return; // 既に削除済み
        const r = snap.data() as any;

        const p1 = r.player1_id as string | null | undefined;
        const p2 = r.player2_id as string | null | undefined;

        if (p1 !== uid && p2 !== uid) {
          throw new HttpsError("permission-denied", "参加者ではありません");
        }

        // 終了済みは変更しない
        if (r.room_status === "finished") return;

        const now = FieldValue.serverTimestamp();

        // player1 が待機中に離脱 -> 部屋削除
        if (p1 === uid && !p2 && r.room_status === "waiting") {
          tx.delete(ref);
          return;
        }

        // player2 が離脱 -> player2_id をnullに戻して waiting
        if (p2 === uid) {
          tx.set(ref, { player2_id: null, room_status: "waiting", updatedAt: now }, { merge: true });
          return;
        }

        // player1 が対戦中に離脱 -> player1_id をnullにしてステータス更新
        if (p1 === uid) {
          tx.set(ref, { player1_id: null, room_status: "player1_left", updatedAt: now }, { merge: true });
        }
      });

      return { ok: true };
    } catch (e: any) {
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", e?.message ?? "internal");
    }
  }
);

export const selectCard = onCall(
  {cors: true, region: "us-central1", minInstances: 0},
  async (request) => {
    ensureApp();
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "認証が必要です");
      const uid = request.auth.uid;
      const {roomId, cardId} = request.data ?? {};
      if (typeof roomId !== "string" || !roomId.trim()) throw new HttpsError("invalid-argument", "roomId 必須");
      if (typeof cardId !== "number") throw new HttpsError("invalid-argument", "cardId 必須(number)");

      const roomRef = admin.firestore().collection("rooms").doc(roomId);
      await admin.firestore().runTransaction(async (tx) => {
        const snap = await tx.get(roomRef);
        if (!snap.exists) throw new HttpsError("not-found", "room が存在しません");
        const r = snap.data() as any;
        const gs = (r.game_state ?? {}) as any;
        if (r.player1_id !== uid && r.player2_id !== uid) throw new HttpsError("permission-denied", "参加者ではありません");

        const patch: any = {game_state: {...gs}};
        if (r.player1_id === uid) {
          patch.game_state.player1_card = cardId;
        } else {
          patch.game_state.player2_card = cardId;
        }
        patch.updatedAt = FieldValue.serverTimestamp();
        tx.set(roomRef, patch, {merge: true});
      });

      return {ok: true};
    } catch (e: any) {
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", e?.message ?? "internal");
    }
  }
);
export const saveGachaResult = onCall(
  {cors: true, region: "us-central1", minInstances: 0},
  async (request) => {
    ensureApp();
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "認証が必要です");
      const uid = request.auth.uid;

      const itemsRaw = request.data?.items ?? request.data?.cardIds;
      if (!Array.isArray(itemsRaw) || itemsRaw.length === 0) {
        throw new HttpsError("invalid-argument", "items または cardIds が必要です");
      }

      // 正規化: [{id:number, qty:number}] 形式に統一
      const items: { id: number; qty: number }[] = itemsRaw.map((v: any) => {
        if (typeof v === "number") return {id: v, qty: 1};
        const id = typeof v?.id === "number" ? v.id : NaN;
        const qty = typeof v?.qty === "number" && v.qty > 0 ? v.qty : 1;
        return {id, qty};
      }).filter((x) => Number.isFinite(x.id) && x.id > 0);

      if (items.length === 0) {
        throw new HttpsError("invalid-argument", "有効なカードIDがありません");
      }

      const db = admin.firestore();
      const userRef = db.collection("users").doc(uid);
      const ownedCol = userRef.collection("owned_cards");
      const cardsCol = db.collection("cards");

      // 任意: 存在確認（cards に存在しないIDを弾く）
      // コストが気になる場合はスキップ可
      const validItems: { id: number; qty: number }[] = [];
      for (const it of items) {
        const snap = await cardsCol.where("id", "==", it.id).limit(1).get();
        if (!snap.empty) validItems.push(it);
      }
      if (validItems.length === 0) {
        throw new HttpsError("not-found", "cards に一致するIDがありません");
      }

      // バッチで更新
      const batch = db.batch();
      const now = FieldValue.serverTimestamp();

      // owned_cards 更新（count と number を両方更新）
      for (const it of validItems) {
        const docRef = ownedCol.doc(String(it.id));
        batch.set(
          docRef,
          {
            id: it.id,
            count: FieldValue.increment(it.qty),
            number: FieldValue.increment(it.qty),
            lastObtainedAt: now,
            firstObtainedAt: now,
          },
          {merge: true}
        );
      }

      // users ドキュメント: owned_card_ids を同期
      batch.set(
        userRef,
        {
          owned_card_ids: FieldValue.arrayUnion(
            ...validItems.map((i) => i.id)
          ),
          updatedAt: now,
        },
        {merge: true}
      );

      // 履歴（任意）
      const historyRef = userRef.collection("gacha_history").doc();
      batch.set(historyRef, {
        items: validItems,
        packId: request.data?.packId ?? null,
        createdAt: now,
      });

      await batch.commit();

      logger.info("saveGachaResult ok", {uid, count: validItems.length});
      return {ok: true, saved: validItems.length, items: validItems};
    } catch (e: any) {
      logger.error("saveGachaResult error", e);
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", e?.message ?? "internal");
    }
  }
);
// 追加: 単一カードをユーザー所持に加算（クライアント直接書き込みの置き換え）
export const addCardToUserCollection = onCall(
  { cors: true, region: "us-central1", minInstances: 0 },
  async (request) => {
    ensureApp();
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "認証が必要です");
      const uid = request.auth.uid;

      const raw = request.data?.cardId ?? request.data?.id;
      const cardId = typeof raw === "number" ? raw : Number(raw);
      if (!Number.isFinite(cardId) || cardId <= 0) {
        throw new HttpsError("invalid-argument", "cardId が不正です");
      }

      const db = admin.firestore();

      // カード存在確認（cards の docId は String(id)）
      const cardDoc = await db.collection("cards").doc(String(cardId)).get();
      if (!cardDoc.exists) {
        throw new HttpsError("not-found", "指定のカードが存在しません");
      }

      const userRef = db.collection("users").doc(uid);
      const ownedRef = userRef.collection("owned_cards").doc(String(cardId));
      const now = FieldValue.serverTimestamp();

      await db.runTransaction(async (tx) => {
        const ownedSnap = await tx.get(ownedRef);
        const ownedExists = ownedSnap.exists;
        tx.set(
          ownedRef,
          {
            id: cardId,
            count: FieldValue.increment(1),
            number: FieldValue.increment(1),
            // 既存なら firstObtainedAt は保持、未取得なら初回取得時刻を設定
            ...(ownedExists ? {} : { firstObtainedAt: now }),
            lastObtainedAt: now,
          },
          { merge: true }
        );

        tx.set(
          userRef,
          {
            owned_card_ids: FieldValue.arrayUnion(cardId),
            updatedAt: now,
          },
          { merge: true }
        );
      });

      logger.info("addCardToUserCollection ok", { uid, cardId });
      return { ok: true, id: cardId };
    } catch (e: any) {
      logger.error("addCardToUserCollection error", e);
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", e?.message ?? "internal");
    }
  }
);

// 追加: 管理権限で cards を投入/更新
export const adminUpsertCards = onCall(
  {cors: true, region: "us-central1", minInstances: 0},
  async (request) => {
    ensureApp();
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "認証が必要です");
      const raw = request.data?.cards;
      if (!Array.isArray(raw) || raw.length === 0) {
        throw new HttpsError("invalid-argument", "cards 配列が必要です");
      }

      const db = admin.firestore();
      const batch = db.batch();
      let upserted = 0;

      for (const c of raw) {
        const id = Number(c?.id);
        const name = typeof c?.name === "string" ? c.name : "";
        const type = typeof c?.type === "string" ? c.type : "";
        const power = Number(c?.power);
        const rank = typeof c?.rank === "string" ? c.rank : "";
        if (!Number.isFinite(id) || id <= 0 || !name || !type || !Number.isFinite(power) || !rank) {
          continue;
        }
        const docRef = db.collection("cards").doc(String(id));
        batch.set(docRef, { id, name, type, power, rank, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
        upserted++;
      }

      if (upserted === 0) {
        throw new HttpsError("invalid-argument", "有効なカードがありません");
      }

      await batch.commit();
      logger.info("adminUpsertCards ok", { uid: request.auth.uid, upserted, total: raw.length });
      return { ok: true, upserted };
    } catch (e: any) {
      const msg = (typeof e?.message === "string" && e.message) || String(e);
      logger.error("adminUpsertCards error", e);
      if (e instanceof HttpsError) throw e;
      if (e?.code === "permission-denied") {
        throw new HttpsError("permission-denied", "Firestore permission denied", { message: msg, code: e?.code, stack: e?.stack });
      }
      throw new HttpsError("internal", "adminUpsertCards failed", { message: msg, code: e?.code, stack: e?.stack });
    }
  }
);

// 追加: 指定IDのカード詳細を一括取得（管理権限、認証必須）
export const fetchCardsByIds = onCall(
  {cors: true, region: "us-central1", minInstances: 0},
  async (request) => {
    ensureApp();
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "認証が必要です");
      const raw = request.data?.ids;
      if (!Array.isArray(raw) || raw.length === 0) {
        throw new HttpsError("invalid-argument", "ids 配列が必要です");
      }
      const ids: number[] = Array.from(
        new Set(
          raw.map((v: any) => Number(v)).filter((n: number) => Number.isFinite(n) && n > 0)
        )
      );
      if (ids.length === 0) {
        throw new HttpsError("invalid-argument", "有効なIDがありません");
      }

      const db = admin.firestore();
      // cards の docId は String(id)
      const refs = ids.slice(0, 300).map((id) => db.collection("cards").doc(String(id)));
      const snaps = await Promise.all(refs.map((r) => r.get()));
      const cards = snaps.filter((s) => s.exists).map((s) => s.data());

      return {ok: true, cards};
    } catch (e: any) {
      logger.error("fetchCardsByIds error", e);
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", e?.message ?? "internal");
    }
  }
);

// 修正: getCardsCount の catch 構文を修正
export const getCardsCount = onCall(
  {cors: true, region: "us-central1", minInstances: 0},
  async () => {
    ensureApp();
    try {
      const snap = await admin.firestore().collection("cards").limit(1).get();
      return {ok: true, hasAny: !snap.empty};
    } catch (e: any) {
      const msg = (typeof e?.message === "string" && e.message) || String(e);
      logger.error("getCardsCount error", e);
      if (e?.code === "permission-denied") {
        throw new HttpsError(
          "permission-denied",
          "Firestore permission denied",
          {message: msg, code: e?.code, stack: e?.stack}
        );
      }
      throw new HttpsError("internal", "getCardsCount failed", {message: msg, code: e?.code, stack: e?.stack});
    }
  }
);

// ガチャ抽選（サーバー集約）
export const drawGacha = onCall(
  { cors: true, region: "us-central1", minInstances: 0 },
  async (request) => {
    ensureApp();
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "認証が必要です");
      const uid = request.auth.uid;

      const raw = request.data?.packRarityLevel;
      const packRarityLevel = Number(raw);
      const rarity = [1, 2, 3, 4].includes(packRarityLevel) ? packRarityLevel : 1;

      // パックレアリティに応じたカードの取得確率を設定
      const rarityProbability: Record<number, Record<string, number>> = {
        1: { S: 5, A: 10, B: 15, C: 30, D: 40 },
        2: { S: 5, A: 10, B: 15, C: 30, D: 40 },
        3: { S: 5, A: 10, B: 15, C: 30, D: 40 },
        4: { S: 5, A: 10, B: 15, C: 30, D: 40 },
      };

      // ランク抽選
      const probs = rarityProbability[rarity];
      const total = Object.values(probs).reduce((a, b) => a + b, 0);
      let r = Math.floor(Math.random() * total);
      let chosenRank: "S" | "A" | "B" | "C" | "D" = "D";
      for (const [rank, p] of Object.entries(probs)) {
        if (r < p) {
          chosenRank = rank as any; break;
        }
        r -= p;
      }

      // ランク別にカード取得 → ランダム1枚
      const col = admin.firestore().collection("cards");
      const snap = await col.where("rank", "==", chosenRank).get();
      if (snap.empty) {
        throw new HttpsError("not-found", `rank=${chosenRank} のカードが見つかりません`);
      }
      const idx = Math.floor(Math.random() * snap.docs.length);
      const doc = snap.docs[idx];
      const card = doc.data() as any; // { id, name, type, power, rank, ... }

      // 所持に加算＋履歴保存（トランザクション）
      const db = admin.firestore();
      const userRef = db.collection("users").doc(uid);
      const ownedRef = userRef.collection("owned_cards").doc(String(card.id));
      const now = FieldValue.serverTimestamp();

      await db.runTransaction(async (tx) => {
        const ownedSnap = await tx.get(ownedRef);
        const exists = ownedSnap.exists;

        tx.set(ownedRef, {
          id: card.id,
          count: FieldValue.increment(1),
          number: FieldValue.increment(1),
          ...(exists ? {} : { firstObtainedAt: now }),
          lastObtainedAt: now,
        }, { merge: true });

        tx.set(userRef, {
          owned_card_ids: FieldValue.arrayUnion(card.id),
          updatedAt: now,
        }, { merge: true });

        const histRef = userRef.collection("gacha_history").doc();
        tx.set(histRef, {
          items: [{ id: card.id, qty: 1 }],
          packRarityLevel: rarity,
          rank: chosenRank,
          createdAt: now,
        });
      });

      // レアリティレベル（表示用）
      const rarityLevel = (() => {
        switch (chosenRank) {
        case "S": return 5;
        case "A": return 4;
        case "B": return 3;
        case "C": return 2;
        default: return 1;
        }
      })();

      // 見た目用のランダム画像インデックス（0..2）
      const imageIndex = Math.floor(Math.random() * 3);

      logger.info("drawGacha ok", { uid, rank: chosenRank, cardId: card.id });
      return { ok: true, card, rank: chosenRank, rarityLevel, imageIndex };
    } catch (e: any) {
      logger.error("drawGacha error", e);
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", e?.message ?? "internal");
    }
  }
);

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// 追加: ユーザー初期化（users/{uid} ドキュメントを確実に作成）
export const ensureUserInitialized = onCall(
  { cors: true, region: "us-central1", minInstances: 0 },
  async (request) => {
    ensureApp();
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "認証が必要です");
      const uid = request.auth.uid;

      const db = admin.firestore();
      const userRef = db.collection("users").doc(uid);

      // トランザクションでユーザードキュメントを作成（存在する場合は何もしない）
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(userRef);
        // 存在しなければ作成
        if (!snap.exists) {
          tx.set(userRef, {
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
            // 空のデッキ初期化（0が5つ）- バトルページが自動補充できるように
            deck: [0, 0, 0, 0, 0],
          });
        }
      });

      logger.info("ensureUserInitialized ok", { uid });
      return { ok: true };
    } catch (e: any) {
      logger.error("ensureUserInitialized error", e);
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", e?.message ?? "internal");
    }
  }
);

// デッキ保存用のCloud Function
export const saveDeck = onCall(
  { cors: true, region: "us-central1", minInstances: 0 },
  async (request) => {
    ensureApp();
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "認証が必要です");
      const uid = request.auth.uid;

      // deckデータのバリデーション
      const deck = request.data?.deck;
      if (!Array.isArray(deck)) {
        throw new HttpsError("invalid-argument", "deck は配列である必要があります");
      }

      // 厳密にnumber[]に変換
      const validDeck: number[] = deck
        .map((v) => typeof v === "number" ? v : parseInt(String(v), 10))
        .filter((n) => Number.isFinite(n) && n > 0);

      if (validDeck.length < 1 || validDeck.length > 25) {
        throw new HttpsError(
          "invalid-argument",
          `deck は1～25枚必要です（現在: ${validDeck.length}枚）`
        );
      }

      const db = admin.firestore();
      const userRef = db.collection("users").doc(uid);

      // ユーザードキュメントの存在確認
      const userSnap = await userRef.get();
      if (!userSnap.exists) {
        // 存在しなければ作成
        await userRef.set({
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          deck: validDeck,
        });
      } else {
        // 存在すれば deck フィールドのみ更新
        await userRef.set(
          { deck: validDeck, updatedAt: FieldValue.serverTimestamp() },
          { merge: true }
        );
      }

      logger.info("saveDeck success", { uid, deckSize: validDeck.length });
      return { ok: true, savedDeck: validDeck };
    } catch (e: any) {
      logger.error("saveDeck error", e);
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", e?.message ?? "internal");
    }
  }
);
