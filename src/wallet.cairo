#[starknet::contract]
pub mod Wallet {
    use starknet::{ContractAddress, get_caller_address, get_contract_address, contract_address_const};
    use starknet::storage::{StoragePointerWriteAccess, StorableStoragePointerReadAccess, StorageMapWriteAccess, StorageMapReadAccess, Map};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use crate::interfaces::iwallet::IWallet;
   
    // Error constants
    const ERROR_ZERO_ADDRESS: felt252 = 'Zero address not allowed';
    const ERROR_VALUE_SHOULD_BE_POSITIVE: felt252 = 'Amount must be positive';
    const ERROR_BALANCE_INSUFFICIENT: felt252 = 'Insufficient balance';
    const ERROR_TOKEN_TRANSFER_FAILED: felt252 = 'Token transfer failed';

    #[storage]
    struct Storage {
        balances: Map::<(ContractAddress, ContractAddress), u256>,
        token1: ContractAddress,
        token2: ContractAddress,
        token3: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    #[event]
    enum Event {
        Deposited: TokenDeposited,
        Withdrawn: TokenWithdrawn,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenDeposited {
        user: ContractAddress,
        token_address: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenWithdrawn {
        user: ContractAddress,
        token_address: ContractAddress,
        amount: u256,
    }
    #[constructor]
    fn constructor(ref self: ContractState, token1: ContractAddress, token2: ContractAddress, token3: ContractAddress) {
        self.token1.write(token1);
        self.token2.write(token2);
        self.token3.write(token3);
    }

    #[abi(embed_v0)]
    pub impl WalletImpl of IWallet<ContractState> {
        fn deposit_token(ref self: ContractState, token_address: ContractAddress, amount: u256) {
    
            self.assert_non_zero_address(token_address);
            assert(amount > 0, ERROR_VALUE_SHOULD_BE_POSITIVE);

            let user = get_caller_address();
            let this_contract = get_contract_address();

            let token1_addr = self.token1.read();
            let token2_addr = self.token2.read();
            let token3_addr = self.token3.read();

            // Check balance and allowance
            self.check_allowance_and_transfer(token1_addr);
            self.check_allowance_and_transfer(token2_addr);
            self.check_allowance_and_transfer(token3_addr);

            
            
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let success = erc20_dispatcher.transfer_from(user, this_contract, amount);
            assert(success, ERROR_TOKEN_TRANSFER_FAILED);

            let current_balance = self.balances.read((user, token_address));
            self.balances.write((user, token_address), current_balance + amount);

            self.emit(Event::Deposited(
                TokenDeposited {
                    user,
                    token_address,
                    amount
                }
            ));
        }

        fn withdraw_token(ref self: ContractState, token_address: ContractAddress, amount: u256, token1:ContractAddress, token2:ContractAddress, token3:ContractAddress) {
            
            self.assert_non_zero_address(token_address);
            assert(amount > 0, ERROR_VALUE_SHOULD_BE_POSITIVE);

            let user = get_caller_address();
            
            let current_balance = self.balances.read((user, token_address));
            assert(current_balance >= amount, ERROR_BALANCE_INSUFFICIENT);

            self.balances.write((user, token_address), current_balance - amount);

            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let success = erc20_dispatcher.transfer(user, amount);
            assert(success, ERROR_TOKEN_TRANSFER_FAILED);

            self.emit(Event::Withdrawn(
                TokenWithdrawn {
                    user,
                    token_address,
                    amount
                }
            ));
        }

        fn get_balance(self: @ContractState, user: ContractAddress, token_address: ContractAddress) -> u256 {
            self.balances.read((user, token_address))
        }

        fn check_allowance_and_transfer(ref self: ContractState, token_addr: ContractAddress) -> u256 {
            let user = get_caller_address();
            let this_contract = get_contract_address();

            let dispatcher = IERC20Dispatcher { contract_address: token_addr };
            let allowed_amount = dispatcher.allowance(user, this_contract);
            assert(allowed_amount >= 0, 'Insufficient allowance');

            dispatcher.transfer_from(user, this_contract, allowed_amount);
            allowed_amount
        }
    }

    #[generate_trait]
    impl InternalFunctionsImpl of InternalFunctionsTrait {
        fn assert_non_zero_address(self: @ContractState, address: ContractAddress) {
            let zero_address = contract_address_const::<0>();
            assert(address != zero_address, ERROR_ZERO_ADDRESS);
        }
    }
}