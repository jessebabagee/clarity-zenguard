import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can start meditation session with valid duration and amount",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    const amount = 1000;
    const duration = 300; // 5 minutes
    
    let block = chain.mineBlock([
      Tx.contractCall("zen_guard", "start-session", [
        types.uint(duration),
        types.uint(amount)
      ], wallet_1.address)
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), true);
    
    let getSession = chain.callReadOnlyFn(
      "zen_guard",
      "get-session-data",
      [types.principal(wallet_1.address)],
      wallet_1.address
    );
    
    let sessionData = getSession.result.expectSome().expectTuple();
    assertEquals(sessionData.locked_amount, types.uint(amount));
    assertEquals(sessionData.duration, types.uint(duration));
    assertEquals(sessionData.completed, types.bool(false));
    assertEquals(sessionData.group_id, types.none());
  }
});

Clarinet.test({
  name: "Can create and join group meditation session",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const creator = accounts.get("wallet_1")!;
    const joiner = accounts.get("wallet_2")!;
    const amount = 1000;
    const duration = 300;
    
    // Create group session
    let block1 = chain.mineBlock([
      Tx.contractCall("zen_guard", "create-group-session", [
        types.uint(duration),
        types.uint(amount)
      ], creator.address)
    ]);
    
    assertEquals(block1.receipts[0].result.expectOk(), types.uint(0));
    
    // Join group session
    let block2 = chain.mineBlock([
      Tx.contractCall("zen_guard", "join-group-session", [
        types.uint(0),
        types.uint(amount)
      ], joiner.address)
    ]);
    
    assertEquals(block2.receipts[0].result.expectOk(), true);
    
    // Verify group data
    let getGroup = chain.callReadOnlyFn(
      "zen_guard",
      "get-group-data",
      [types.uint(0)],
      creator.address
    );
    
    let groupData = getGroup.result.expectSome().expectTuple();
    assertEquals(groupData.creator, types.principal(creator.address));
    assertEquals(groupData.locked_amount, types.uint(amount));
    assertEquals(groupData.duration, types.uint(duration));
    assertEquals(groupData.completed, types.bool(false));
    
    let members = groupData.members.expectList();
    assertEquals(members.length, 2);
  }
});

Clarinet.test({
  name: "Can complete group meditation session",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const creator = accounts.get("wallet_1")!;
    const joiner = accounts.get("wallet_2")!;
    const amount = 1000;
    const duration = 300;
    
    // Create and join group session
    let block1 = chain.mineBlock([
      Tx.contractCall("zen_guard", "create-group-session", [
        types.uint(duration),
        types.uint(amount)
      ], creator.address),
      Tx.contractCall("zen_guard", "join-group-session", [
        types.uint(0),
        types.uint(amount)
      ], joiner.address)
    ]);
    
    // Mine blocks to simulate time passing
    chain.mineEmptyBlockUntil(chain.blockHeight + duration + 1);
    
    // End sessions
    let block2 = chain.mineBlock([
      Tx.contractCall("zen_guard", "end-session", [], creator.address),
      Tx.contractCall("zen_guard", "end-session", [], joiner.address)
    ]);
    
    assertEquals(block2.receipts[0].result.expectOk(), true);
    assertEquals(block2.receipts[1].result.expectOk(), true);
    
    // Verify stats updated
    let getStats = chain.callReadOnlyFn(
      "zen_guard",
      "get-user-stats",
      [types.principal(creator.address)],
      creator.address
    );
    
    let stats = getStats.result.expectTuple();
    assertEquals(stats.total_sessions, types.uint(1));
    assertEquals(stats.total_time, types.uint(duration));
    assertEquals(stats.total_locked, types.uint(amount));
    assertEquals(stats.total_group_sessions, types.uint(1));
  }
});
