import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
admin.initializeApp();
const db = admin.firestore();

// On habit write, ensure user doc and simple leaderboard aggregation
exports.onHabitWrite = functions.firestore
  .document('users/{uid}/habits/{hid}')
  .onWrite(async (change, context) => {
    const uid = context.params.uid as string;
    const after = change.after.exists ? change.after.data()! : null;
    if (!after) return;

    const userRef = db.collection('users').doc(uid);
    await userRef.set({ displayName: 'User', totalXP: admin.firestore.FieldValue.increment(0) }, { merge: true });

    const lbRef = db.collection('leaderboards').doc('global');
    await db.runTransaction(async (tx) => {
      const lbSnap = await tx.get(lbRef);
      const board = lbSnap.exists ? lbSnap.data()! : { entries: {} as any };
      const userSnap = await tx.get(userRef);
      const totalXP = (userSnap.data()?.totalXP ?? 0) as number;
      board.entries[uid] = { totalXP };
      tx.set(lbRef, board, { merge: true });
    });
  });
