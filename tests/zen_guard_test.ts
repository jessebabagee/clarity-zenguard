[... previous test content ...]

Clarinet.test({
  name: "Contract owner can pause and unpause contract",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const user1 = accounts.get("wallet_1")!;
    
    // Pause contract
    let block1 = chain.mineBlock([
      Tx.contractCall("zen_guard", "pause-contract", [], deployer.address)
    ]);
    assertEquals(block1.receipts[0].result.expectOk(), true);
    
    // Attempt to start session while paused
    let block2 = chain.mineBlock([
      Tx.contractCall("zen_guard", "start-session", [
        types.uint(300),
        types.uint(1000)
      ], user1.address)
    ]);
    assertEquals(block2.receipts[0].result.expectErr(), 108);
    
    // Unpause contract
    let block3 = chain.mineBlock([
      Tx.contractCall("zen_guard", "unpause-contract", [], deployer.address)
    ]);
    assertEquals(block3.receipts[0].result.expectOk(), true);
  }
});
