Clarinet.test({
  name: "Verify session parameters and cooldown period",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user1 = accounts.get("wallet_1")!;
    
    // Test successful session start
    let block1 = chain.mineBlock([
      Tx.contractCall("zen_guard", "start-session", [
        types.uint(300),
        types.uint(1000)
      ], user1.address)
    ]);
    assertEquals(block1.receipts[0].result.expectOk(), true);
    
    // Test cooldown period
    let block2 = chain.mineBlock([
      Tx.contractCall("zen_guard", "start-session", [
        types.uint(300),
        types.uint(1000)
      ], user1.address)
    ]);
    assertEquals(block2.receipts[0].result.expectErr(), 109);
    
    // Test amount limit
    let block3 = chain.mineBlock([
      Tx.contractCall("zen_guard", "start-session", [
        types.uint(300),
        types.uint(2000000000)
      ], user1.address)
    ]);
    assertEquals(block3.receipts[0].result.expectErr(), 110);
  }
});

[... rest of original tests ...]
