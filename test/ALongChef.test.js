const { expectRevert, time } = require('@openzeppelin/test-helpers');
const LongToken = artifacts.require('LongToken');
const LongChef = artifacts.require('LongChef');
const MockERC20 = artifacts.require('MockERC20');

contract('LongChef', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {
        this.long = await LongToken.new({ from: alice });
    });

    it('should set correct state variables', async () => {
        this.chef = await LongChef.new(this.long.address, dev, '1000', '0', '1000', { from: alice });
        await this.long.transferOwnership(this.chef.address, { from: alice });
        const long = await this.chef.long();
        const devaddr = await this.chef.devaddr();
        const owner = await this.long.owner();
        assert.equal(long.valueOf(), this.long.address);
        assert.equal(devaddr.valueOf(), dev);
        assert.equal(owner.valueOf(), this.chef.address);
    });

    it('should allow dev and only dev to update dev', async () => {
        this.chef = await LongChef.new(this.long.address, dev, '1000', '0', '1000', { from: alice });
        assert.equal((await this.chef.devaddr()).valueOf(), dev);
        await expectRevert(this.chef.dev(bob, { from: bob }), 'dev: wut?');
        await this.chef.dev(bob, { from: dev });
        assert.equal((await this.chef.devaddr()).valueOf(), bob);
        await this.chef.dev(alice, { from: bob });
        assert.equal((await this.chef.devaddr()).valueOf(), alice);
    })

    context('With ERC/LP token added to the field', () => {
        beforeEach(async () => {
            this.lp = await MockERC20.new('LPToken', 'LP', '10000000000', { from: minter });
            await this.lp.transfer(alice, '1000', { from: minter });
            await this.lp.transfer(bob, '1000', { from: minter });
            await this.lp.transfer(carol, '1000', { from: minter });
            this.lp2 = await MockERC20.new('LPToken2', 'LP2', '10000000000', { from: minter });
            await this.lp2.transfer(alice, '1000', { from: minter });
            await this.lp2.transfer(bob, '1000', { from: minter });
            await this.lp2.transfer(carol, '1000', { from: minter });
        });

        it('should LONG 126000', async () => {
            this.chef = await LongChef.new(this.long.address, dev, '100', '1000', '126000', { from: alice });
            await this.chef.add('100', this.lp.address, true);
            await this.lp.approve(this.chef.address, '1000', { from: bob });
            await this.chef.deposit(0, '100', { from: bob });
            assert.equal((await this.lp.balanceOf(bob)).valueOf(), '900');
            await this.chef.emergencyWithdraw(0, { from: bob });
            assert.equal((await this.lp.balanceOf(bob)).valueOf(), '1000');
        });

        it('should give out LONGs only after farming time 2', async () => {
            /*
            The first 126,000 blocks (~18 days) is the bonus period. We divide the bonus period into 6 stages, each of which is 21,000 blocks (~3 days). The distribution of LONG tokens in these 6 stages is planned as follows:
            1~21,000 blocks, 1000 tokens minted per block
            21,001~42,000 blocks, 900 tokens minted per block
            42,001~63,000 blocks, 800 tokens minted per block
            63,001~84,000 blocks, 700 tokens minted per block
            84,001~105,000 blocks, 600 tokens minted per block
            105,001~126,000 blocks, 500 tokens minted per block
            After the bonus period ends, 100 tokens will be minted per block.
            */
            this.chef = await LongChef.new(this.long.address, dev, '100', '65562', '191562', { from: alice });
            await this.long.transferOwnership(this.chef.address, { from: alice });
            await this.chef.add('1', this.lp.address, true);
            await this.lp.approve(this.chef.address, '1000', { from: bob });
            await this.chef.deposit(0, '100', { from: bob });
            await this.chef.deposit(0, '0', { from: bob }); //1000
            await this.chef.deposit(0, '0', { from: bob }); //2000
            await this.chef.deposit(0, '0', { from: bob });
            await this.chef.deposit(0, '0', { from: bob });
            await this.chef.deposit(0, '0', { from: bob });
            await this.chef.deposit(0, '0', { from: bob });
            await this.chef.deposit(0, '0', { from: bob });
            await this.chef.deposit(0, '0', { from: bob });
            await this.chef.deposit(0, '0', { from: bob });
            await this.chef.deposit(0, '0', { from: bob });

            assert.equal((await this.long.balanceOf(bob)).valueOf(), '10000');
            assert.equal((await this.long.balanceOf(dev)).valueOf(), '1000');
            console.log( (await this.long.totalSupply()).valueOf() );
            assert.equal((await this.long.totalSupply()).valueOf(), '11000');
        });
    });
});
