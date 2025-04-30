use starknet::ContractAddress;
#[starknet::contract]
pub mod message_store_proxy {
    use starknet::syscalls::replace_class_syscall;
use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, class_hash::ClassHash,};
    use crate::base::errors::Errors::{ERROR_ZERO_ADDRESS, ERROR_UNAUTHORIZED};

    // We need to maintain the same struct definition as in the implementation
    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct Message {
        id: u256,
        sender: ContractAddress,
        receiver: ContractAddress,
        content_hash: felt252,
        timestamp: u64,
    }

    #[storage]
    struct Storage {
        // Proxy-specific storage
        implementation_hash: ClassHash,
        admin: ContractAddress,
        
        // Original contract storage
        user_registry: ContractAddress,
        message_counter: u256,
        messages: Map<(felt252, u256), Message>,
        conversation_message_count: Map<felt252, u256>,
        user_conversations: Map<ContractAddress, Array<felt252>>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded,
        AdminChanged: AdminChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        new_implementation: ClassHash,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminChanged {
        previous_admin: ContractAddress,
        new_admin: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        initial_implementation: ClassHash, 
        initial_admin: ContractAddress,
        user_registry_address: ContractAddress
    ) {
        assert(!initial_admin.is_zero(), ERROR_ZERO_ADDRESS);
        assert(!user_registry_address.is_zero(), ERROR_ZERO_ADDRESS);
        
        self.implementation_hash.write(initial_implementation);
        self.admin.write(initial_admin);
        self.user_registry.write(user_registry_address);
        self.message_counter.write(0);
    }

    #[abi(embed_v0)]
    impl ProxyAdmin of super::IProxyAdmin<ContractState> {
        // Upgrade the implementation contract
        fn upgrade(ref self: ContractState, new_implementation: ClassHash) {
            // Only admin can upgrade
            let caller = get_caller_address();
            let admin = self.admin.read();
            assert(caller == admin, ERROR_UNAUTHORIZED);

            // Update implementation hash
            self.implementation_hash.write(new_implementation);
            
            // Replace class hash with new implementation
            replace_class_syscall(new_implementation).unwrap();
            
            // Emit event
            self.emit(Event::Upgraded(Upgraded { new_implementation }));
        }
        
        // Change admin
        fn change_admin(ref self: ContractState, new_admin: ContractAddress) {
            assert(!new_admin.is_zero(), ERROR_ZERO_ADDRESS);
            
            // Only current admin can change admin
            let caller = get_caller_address();
            let current_admin = self.admin.read();
            assert(caller == current_admin, ERROR_UNAUTHORIZED);
            
            // Update admin
            self.admin.write(new_admin);
            
            // Emit event
            self.emit(Event::AdminChanged(AdminChanged { 
                previous_admin: current_admin, 
                new_admin 
            }));
        }
        
        // Get current implementation hash
        fn get_implementation(self: @ContractState) -> ClassHash {
            self.implementation_hash.read()
        }
        
        // Get current admin
        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }
    }
}

// Interface for proxy admin functions
#[starknet::interface]
pub trait IProxyAdmin<TContractState> {
    fn upgrade(ref self: TContractState, new_implementation: starknet::class_hash::ClassHash);
    fn change_admin(ref self: TContractState, new_admin: ContractAddress);
    fn get_implementation(self: @TContractState) -> starknet::class_hash::ClassHash;
    fn get_admin(self: @TContractState) -> ContractAddress;
}
