const { expectRevert } = require('@openzeppelin/test-helpers');
const LongToken = artifacts.require('LongToken');

contract('LongToken', ([alice, bob, carol]) => {
    beforeEach(async () => {
        this.long = await LongToken.new({ from: alice });
    });

    it('should have correct name and symbol and decimal', async () => {
        const name = await this.long.name();
        const symbol = await this.long.symbol();
        const decimals = await this.long.decimals();
        assert.equal(name.valueOf(), 'LongToken');
        assert.equal(symbol.valueOf(), 'LONG');
        assert.equal(decimals.valueOf(), '18');
    });

    it('should only allow owner to mint token', async () => {
        await this.long.mint(alice, '100', { from: alice });
        await this.long.mint(bob, '1000', { from: alice });
        await expectRevert(
            this.long.mint(carol, '1000', { from: bob }),
            'Ownable: caller is not the owner',
        );
        const totalSupply = await this.long.totalSupply();
        const aliceBal = await this.long.balanceOf(alice);
        const bobBal = await this.long.balanceOf(bob);
        const carolBal = await this.long.balanceOf(carol);
        assert.equal(totalSupply.valueOf(), '1100');
        assert.equal(aliceBal.valueOf(), '100');
        assert.equal(bobBal.valueOf(), '1000');
        assert.equal(carolBal.valueOf(), '0');
    });

    it('should supply token transfers properly', async () => {
        await this.long.mint(alice, '100', { from: alice });
        await this.long.mint(bob, '1000', { from: alice });
        await this.long.transfer(carol, '10', { from: alice });
        await this.long.transfer(carol, '100', { from: bob });
        const totalSupply = await this.long.totalSupply();
        const aliceBal = await this.long.balanceOf(alice);
        const bobBal = await this.long.balanceOf(bob);
        const carolBal = await this.long.balanceOf(carol);
        assert.equal(totalSupply.valueOf(), '1100');
        assert.equal(aliceBal.valueOf(), '90');
        assert.equal(bobBal.valueOf(), '900');
        assert.equal(carolBal.valueOf(), '110');
    });

    it('should fail if you try to do bad transfers', async () => {
        await this.long.mint(alice, '100', { from: alice });
        await expectRevert(
            this.long.transfer(carol, '110', { from: alice }),
            'ERC20: transfer amount exceeds balance',
        );
        await expectRevert(
            this.long.transfer(carol, '1', { from: bob }),
            'ERC20: transfer amount exceeds balance',
        );
    });
  });
