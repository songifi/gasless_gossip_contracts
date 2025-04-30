#[starknet::contract]
mod Wallet {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::ClassHash;
    use core::array::ArrayTrait;
    use core::traits::Into;
    use core::traits::TryInto;
    use core::option::OptionTrait;
    use starknet::storage::{StorageMapWriteAccess, StorageMapReadAccess, Map};
    // use zeroable::Zeroable;
    use contract::interfaces::iwallet::IWallet;

    // Import IERC20 interface
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    // Storage for user balances
    #[storage]
    struct Storage {
        // Mapping of user address -> token address -> balance
        balances: Map::<(ContractAddress, ContractAddress), u256>,
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Deposited: TokenDeposited,
        Withdrawn: TokenWithdrawn,
    }

    // Event emitted when tokens are deposited
    #[derive(Drop, starknet::Event)]
    struct TokenDeposited {
        user: ContractAddress,
        token: ContractAddress,
        amount: u256,
    }

    // Event emitted when tokens are withdrawn
    #[derive(Drop, starknet::Event)]
    struct TokenWithdrawn {
        user: ContractAddress,
        token: ContractAddress,
        amount: u256,
    }

    use super::*;

    // Contract implementation
    #[abi(embed_v0)]
    impl WalletImpl of IWallet<ContractState> {

        // Deposit tokens into the wallet
        fn deposit_token(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            // Get caller address
            let user = get_caller_address();
            
            // Ensure amount is not zero
            assert(amount > 0, 'Amount must be positive');
            
            // Create token dispatcher
            let token = IERC20Dispatcher { contract_address: token_address };
            
            // Transfer tokens from user to contract
            token.transfer_from(user, starknet::get_contract_address(), amount);
            
            // Update balance
            let current_balance = self.get_balance(user, token_address);
            self.balances.write((user, token_address), current_balance + amount);
            
            // Emit deposit event
            self.emit(TokenDeposited { user, token: token_address, amount });
        }

        // Withdraw tokens from the wallet
        fn withdraw_token(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            // Get caller address
            let user = get_caller_address();
            
            // Ensure amount is not zero
            assert(amount > 0, 'Amount must be positive');
            
            // Get current balance
            let current_balance = self.get_balance(user, token_address);
            
            // Check if user has sufficient balance
            assert(current_balance >= amount, 'Insufficient balance');
            
            // Update balance
            self.balances.write((user, token_address), current_balance - amount);
            
            // Create token dispatcher
            let token = IERC20Dispatcher { contract_address: token_address };
            
            // Transfer tokens from contract to user
            token.transfer(user, amount);
            
            // Emit withdrawal event
            self.emit(TokenWithdrawn { user, token: token_address, amount });
        }

        // Get user balance for specific token
        fn get_balance(self: @ContractState, user: ContractAddress, token_address: ContractAddress) -> u256 {
            self.balances.read((user, token_address))
        }
    }

    // Constructor for contract initialization
    #[constructor]
    fn constructor(ref self: ContractState) {
        // Initialize contract if needed
    }
}
