#[starknet::contract]
pub mod tipping {
    // Imports
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::base::errors::Errors::{
        ERROR_ZERO_ADDRESS, ERROR_NOT_REGISTERED, ERROR_TOKEN_NOT_SET, ERROR_INSUFFICIENT_ALLOWANCE
    };
    use crate::interfaces::itipping::ITipping;
    use crate::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use crate::interfaces::igossip::{iGossipDispatcher, iGossipDispatcherTrait};

    // Tip struct to record tipping details
    #[derive(Drop, Serde, starknet::Store, Clone)]
    pub struct Tip {
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        timestamp: u64,
    }

    // Storage
    #[storage]
    struct Storage {
        token_contract: ContractAddress,
        gossip_contract: ContractAddress,
        tips: Map<(ContractAddress, u64), Tip>, // Map of (receiver, timestamp) to Tip
        tips_count: Map<ContractAddress, u64>, // Count of tips received by an address
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TokenTipped: TokenTipped,
        UserRewarded: UserRewarded,
        TokenContractUpdated: TokenContractUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenTipped {
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct UserRewarded {
        to: ContractAddress,
        amount: u256,
        activity_type: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenContractUpdated {
        old_token_contract: ContractAddress,
        new_token_contract: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, gossip_address: ContractAddress) {
        assert(!gossip_address.is_zero(), ERROR_ZERO_ADDRESS);
        self.gossip_contract.write(gossip_address);
    }

    #[abi(embed_v0)]
    impl TippingImpl of ITipping<ContractState> {
        fn tip_user(ref self: ContractState, to: ContractAddress, amount: u256) {
            // Validate inputs
            assert(!to.is_zero(), ERROR_ZERO_ADDRESS);
            assert(amount.low != 0 || amount.high != 0, 'Amount cannot be zero');

            // Ensure token contract is set
            let token_contract = self.token_contract.read();
            assert(!token_contract.is_zero(), ERROR_TOKEN_NOT_SET);

            // Ensure users are registered
            let gossip_contract = iGossipDispatcher { contract_address: self.gossip_contract.read() };
            assert(gossip_contract.is_address_registered(to), ERROR_NOT_REGISTERED);

            let caller = get_caller_address();
            assert(gossip_contract.is_address_registered(caller), ERROR_NOT_REGISTERED);

            // Transfer tokens using transferFrom (requires prior approval)
            let token = IERC20Dispatcher { contract_address: token_contract };
            
            // Check if the caller has approved enough tokens
            let allowance = token.allowance(caller, starknet::get_contract_address());
            assert(allowance >= amount, ERROR_INSUFFICIENT_ALLOWANCE);
            
            // Transfer tokens from sender to recipient
            let transfer_result = token.transfer_from(caller, to, amount);
            assert(transfer_result, 'Token transfer failed');

            // Record the tip
            let timestamp = get_block_timestamp();
            let tip_count = self.tips_count.read(to);
            let new_tip_count = tip_count + 1;
            
            let tip = Tip {
                from: caller,
                to: to,
                amount: amount,
                timestamp: timestamp,
            };
            
            self.tips.write((to, tip_count), tip);
            self.tips_count.write(to, new_tip_count);

            // Emit event
            self.emit(
                Event::TokenTipped(
                    TokenTipped {
                        from: caller,
                        to: to,
                        amount: amount,
                        timestamp: timestamp,
                    }
                )
            );
        }

        fn reward_user_for_activity(
            ref self: ContractState, to: ContractAddress, amount: u256, activity_type: felt252
        ) {
            // Placeholder for future reward logic
            // This function will be expanded in future versions with specific reward mechanics
            
            // Validate inputs
            assert(!to.is_zero(), ERROR_ZERO_ADDRESS);
            assert(amount.low != 0 || amount.high != 0, 'Amount cannot be zero');

            // Ensure token contract is set
            let token_contract = self.token_contract.read();
            assert(!token_contract.is_zero(), ERROR_TOKEN_NOT_SET);

            // Ensure user is registered
            let gossip_contract = iGossipDispatcher { contract_address: self.gossip_contract.read() };
            assert(gossip_contract.is_address_registered(to), ERROR_NOT_REGISTERED);

            // Emit event for tracking purposes
            let timestamp = get_block_timestamp();
            self.emit(
                Event::UserRewarded(
                    UserRewarded {
                        to: to,
                        amount: amount,
                        activity_type: activity_type,
                        timestamp: timestamp,
                    }
                )
            );
        }

        fn set_token_contract(ref self: ContractState, token_contract: ContractAddress) {
            assert(!token_contract.is_zero(), ERROR_ZERO_ADDRESS);
            
            let old_token_contract = self.token_contract.read();
            self.token_contract.write(token_contract);
            
            self.emit(
                Event::TokenContractUpdated(
                    TokenContractUpdated {
                        old_token_contract: old_token_contract,
                        new_token_contract: token_contract,
                    }
                )
            );
        }

        fn get_token_contract(self: @ContractState) -> ContractAddress {
            self.token_contract.read()
        }
    }
} 