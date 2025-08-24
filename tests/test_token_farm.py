import pytest

REWARD_PER_BLOCK = 1e18


@pytest.fixture
def deploy_contracts(accounts, project):
    owner = accounts[0]
    alice = accounts[1]
    bob = accounts[2]

    dapp_token = owner.deploy(project.DappToken, owner.address)
    lp_token = owner.deploy(project.LPToken, owner.address)
    token_farm = owner.deploy(project.TokenFarm, dapp_token.address, lp_token.address)

    dapp_token.transferOwnership(token_farm.address, sender=owner)

    return owner, alice, bob, dapp_token, lp_token, token_farm


def test_deposit_claim_withdraw(deploy_contracts, chain):
    owner, alice, bob, dapp_token, lp_token, token_farm = deploy_contracts

    # Mint LP tokens
    lp_token.mint(alice.address, 1000, sender=owner)
    lp_token.mint(bob.address, 500, sender=owner)

    # Alice deposita 100
    lp_token.approve(token_farm.address, 100, sender=alice)
    token_farm.deposit(100, sender=alice)

    # Bob deposita 300
    lp_token.approve(token_farm.address, 300, sender=bob)
    token_farm.deposit(300, sender=bob)
    print(token_farm.checkpoints(alice.address))
    print(token_farm.checkpoints(bob.address))

    # Minar 10 bloques
    chain.mine(10)

    # Distribuir recompensas
    token_farm.distributeRewardsAll(sender=owner)

    # Verificar pendingRewards
    pending_alice = token_farm.pendingRewards(alice.address)
    pending_bob = token_farm.pendingRewards(bob.address)

    expected_alice = int(REWARD_PER_BLOCK * 13 * 100 / 400)
    expected_bob = int(REWARD_PER_BLOCK * 11 * 300 / 400)

    print(token_farm.checkpoints(alice.address))
    print(token_farm.checkpoints(bob.address))

    assert pending_alice == expected_alice  # 3.5
    assert pending_bob == expected_bob

    # Reclamar recompensas
    alice_before = dapp_token.balanceOf(alice.address)
    token_farm.claimRewards(sender=alice)
    alice_after = dapp_token.balanceOf(alice.address)
    assert alice_after - alice_before == pending_alice

    bob_before = dapp_token.balanceOf(bob.address)
    token_farm.claimRewards(sender=bob)
    bob_after = dapp_token.balanceOf(bob.address)
    assert bob_after - bob_before == pending_bob

    # Retirar staking
    alice_lp_before = lp_token.balanceOf(alice.address)
    token_farm.withdraw(sender=alice)
    alice_lp_after = lp_token.balanceOf(alice.address)
    assert alice_lp_after - alice_lp_before == 100
    assert token_farm.stakingBalance(alice.address) == 0

    bob_lp_before = lp_token.balanceOf(bob.address)
    token_farm.withdraw(sender=bob)
    bob_lp_after = lp_token.balanceOf(bob.address)
    assert bob_lp_after - bob_lp_before == 300
    assert token_farm.stakingBalance(bob.address) == 0
