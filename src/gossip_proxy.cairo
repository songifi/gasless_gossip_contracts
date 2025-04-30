use starknet::ContractAddress;
#[starknet::contract]
pub mod gossip_proxy {
    use core::num::traits::Zero;
    use core::starknet::SyscallResultTrait;
    use starknet::class_hash::ClassHash;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::syscalls::replace_class_syscall;
    use starknet::{ContractAddress, SyscallResult, get_block_timestamp, get_caller_address};
    use crate::base::errors::Errors::{ERROR_UNAUTHORIZED, ERROR_ZERO_ADDRESS};
    use super::IProxyAdmin;

    // User struct - we need to maintain the same storage layout
    // as the implementation contract
    #[derive(Drop, Serde, PartialEq, starknet::Store, Clone)]
    pub struct User {
        username: felt252, // Username (unique)
        profile_hash: felt252, // IPFS hash or similar for avatar/bio
        timestamp: u64 // Registration timestamp
    }

    // Storage - same structure as implementation
    // plus implementation class hash and admin
    #[storage]
    struct Storage {
        // Implementation contract class hash
        implementation_hash: ClassHash,
        // Admin address that can upgrade the contract
        admin: ContractAddress,
        // Original contract storage
        username_to_address: Map<felt252, ContractAddress>,
        address_to_user: Map<ContractAddress, User>,
        is_registered: Map<ContractAddress, bool>,
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
        ref self: ContractState, initial_implementation: ClassHash, initial_admin: ContractAddress,
    ) {
        assert(!initial_admin.is_zero(), ERROR_ZERO_ADDRESS);
        self.implementation_hash.write(initial_implementation);
        self.admin.write(initial_admin);
    }

    #[abi(embed_v0)]
    impl ProxyAdmin of IProxyAdmin<ContractState> {
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
            self
                .emit(
                    Event::AdminChanged(AdminChanged { previous_admin: current_admin, new_admin }),
                );
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
