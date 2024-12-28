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
    
    // Verify session data
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
  }
});

Clarinet.test({
  name: "Cannot start session with invalid duration",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("zen_guard", "start-session", [
        types.uint(100), // Less than minimum time
        types.uint(1000)
      ], wallet_1.address)
    ]);
    
    assertEquals(block.receipts[0].result.expectErr(), types.uint(101));
  }
});

Clarinet.test({
  name: "Can complete meditation session after duration",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    const amount = 1000;
    const duration = 300;
    
    // Start session
    let block1 = chain.mineBlock([
      Tx.contractCall("zen_guard", "start-session", [
        types.uint(duration),
        types.uint(amount)
      ], wallet_1.address)
    ]);
    
    // Mine blocks to simulate time passing
    chain.mineEmptyBlockUntil(chain.blockHeight + duration + 1);
    
    // End session
    let block2 = chain.mineBlock([
      Tx.contractCall("zen_guard", "end-session", [], wallet_1.address)
    ]);
    
    assertEquals(block2.receipts[0].result.expectOk(), true);
    
    // Verify stats updated
    let getStats = chain.callReadOnlyFn(
      "zen_guard",
      "get-user-stats",
      [types.principal(wallet_1.address)],
      wallet_1.address
    );
    
    let stats = getStats.result.expectTuple();
    assertEquals(stats.total_sessions, types.uint(1));
    assertEquals(stats.total_time, types.uint(duration));
    assertEquals(stats.total_locked, types.uint(amount));
  }
});