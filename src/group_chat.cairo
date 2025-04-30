#[starknet::contract]
pub mod GroupChat {
    use starknet::{
        get_caller_address, ContractAddress, contract_address_const,
    };
    use starknet::storage::Map;
    
    use contract::interfaces::igossip::{iGossipDispatcher, iGossipDispatcherTrait};
    use contract::interfaces::igroupchat::IGroupChat;

    // Errors
    const ERROR_UNAUTHORIZED: felt252 = 'Unauthorized action';
    const ERROR_GROUP_NOT_FOUND: felt252 = 'Group does not exist';
    const ERROR_ALREADY_MEMBER: felt252 = 'Address is already a member';
    const ERROR_NOT_MEMBER: felt252 = 'Address is not a member';
    const ERROR_ZERO_ADDRESS: felt252 = 'Zero address not allowed';
    const ERROR_REGISTRY_REQUIRED: felt252 = 'User must be registered';

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        GroupCreated: GroupCreated,
        MemberAdded: MemberAdded,
        MemberRemoved: MemberRemoved,
        AdminChanged: AdminChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct GroupCreated {
        #[key]
        group_id: felt252,
        #[key]
        admin: ContractAddress,
        metadata_uri: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct MemberAdded {
        #[key]
        group_id: felt252,
        #[key]
        member: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct MemberRemoved {
        #[key]
        group_id: felt252,
        #[key]
        member: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminChanged {
        #[key]
        group_id: felt252,
        previous_admin: ContractAddress,
        new_admin: ContractAddress,
    }

    #[storage]
    struct Storage {
        // User registry contract address
        registry_address: ContractAddress,
        // Group counter for generating unique IDs
        group_counter: felt252,
        // Group metadata
        group_metadata: Map<felt252, felt252>,
        // Group admins
        group_admins: Map<felt252, ContractAddress>,
        // Group members (group_id => address => is_member)
        group_members: Map<(felt252, ContractAddress), bool>,
        // Member groups (address => group_id => is_member) - for quick lookups
        member_groups: Map<(ContractAddress, felt252), bool>,
        // Group members count
        group_members_count: Map<felt252, u32>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, registry_address: ContractAddress) {
        self.registry_address.write(registry_address);
        self.group_counter.write(1);
    }

    #[abi(embed_v0)]
    impl GroupChatImpl of IGroupChat<ContractState> {
        fn create_group(ref self: ContractState, metadata_uri: felt252) -> felt252 {
            // Get caller address
            let caller = get_caller_address();
            
            // Check if caller is registered in the user registry
            let registry = iGossipDispatcher { contract_address: self.registry_address.read() };
            assert(registry.is_address_registered(caller), ERROR_REGISTRY_REQUIRED);
            
            // Generate a unique group ID
            let group_id = self.group_counter.read();
            
            // Increment group counter for next group
            self.group_counter.write(group_id + 1);
            
            // Set group metadata and admin
            self.group_metadata.write(group_id, metadata_uri);
            self.group_admins.write(group_id, caller);
            
            // Add the creator as the first member
            self.group_members.write((group_id, caller), true);
            self.member_groups.write((caller, group_id), true);
            self.group_members_count.write(group_id, 1);
            
            // Emit group created event
            self.emit(GroupCreated { group_id, admin: caller, metadata_uri });
            
            // Return the group ID
            group_id
        }

        fn add_member(ref self: ContractState, group_id: felt252, member: ContractAddress) {
            // Check that member address is not zero
            assert(member != contract_address_const::<0>(), ERROR_ZERO_ADDRESS);
            
            // Ensure group exists
            assert(self.group_metadata.read(group_id) != 0, ERROR_GROUP_NOT_FOUND);
            
            // Ensure caller is the admin
            let caller = get_caller_address();
            assert(self.group_admins.read(group_id) == caller, ERROR_UNAUTHORIZED);
            
            // Check if user is registered in the registry
            let registry = iGossipDispatcher { contract_address: self.registry_address.read() };
            assert(registry.is_address_registered(member), ERROR_REGISTRY_REQUIRED);
            
            // Check if already a member
            assert(!self.group_members.read((group_id, member)), ERROR_ALREADY_MEMBER);
            
            // Add member
            self.group_members.write((group_id, member), true);
            self.member_groups.write((member, group_id), true);
            
            // Increment member count
            let current_count = self.group_members_count.read(group_id);
            self.group_members_count.write(group_id, current_count + 1);
            
            // Emit event
            self.emit(MemberAdded { group_id, member });
        }

        fn remove_member(ref self: ContractState, group_id: felt252, member: ContractAddress) {
            // Ensure group exists
            assert(self.group_metadata.read(group_id) != 0, ERROR_GROUP_NOT_FOUND);
            
            // Ensure caller is the admin
            let caller = get_caller_address();
            assert(self.group_admins.read(group_id) == caller, ERROR_UNAUTHORIZED);
            
            // Check that member is not the admin (admin can't be removed)
            assert(member != self.group_admins.read(group_id), ERROR_UNAUTHORIZED);
            
            // Check if member is in the group
            assert(self.group_members.read((group_id, member)), ERROR_NOT_MEMBER);
            
            // Remove member
            self.group_members.write((group_id, member), false);
            self.member_groups.write((member, group_id), false);
            
            // Decrement member count
            let current_count = self.group_members_count.read(group_id);
            self.group_members_count.write(group_id, current_count - 1);
            
            // Emit event
            self.emit(MemberRemoved { group_id, member });
        }

        fn change_admin(ref self: ContractState, group_id: felt252, new_admin: ContractAddress) {
            // Check that new admin address is not zero
            assert(new_admin != contract_address_const::<0>(), ERROR_ZERO_ADDRESS);
            
            // Ensure group exists
            assert(self.group_metadata.read(group_id) != 0, ERROR_GROUP_NOT_FOUND);
            
            // Ensure caller is the current admin
            let caller = get_caller_address();
            let current_admin = self.group_admins.read(group_id);
            assert(current_admin == caller, ERROR_UNAUTHORIZED);
            
            // Check if new admin is registered in the registry
            let registry = iGossipDispatcher { contract_address: self.registry_address.read() };
            assert(registry.is_address_registered(new_admin), ERROR_REGISTRY_REQUIRED);
            
            // Ensure new admin is a member already
            assert(self.group_members.read((group_id, new_admin)), ERROR_NOT_MEMBER);
            
            // Change admin
            self.group_admins.write(group_id, new_admin);
            
            // Emit event
            self.emit(AdminChanged { 
                group_id, 
                previous_admin: current_admin, 
                new_admin 
            });
        }

        // View functions
        fn get_group_metadata(self: @ContractState, group_id: felt252) -> felt252 {
            // Ensure group exists
            assert(self.group_metadata.read(group_id) != 0, ERROR_GROUP_NOT_FOUND);
            
            self.group_metadata.read(group_id)
        }

        fn get_group_admin(self: @ContractState, group_id: felt252) -> ContractAddress {
            // Ensure group exists
            assert(self.group_metadata.read(group_id) != 0, ERROR_GROUP_NOT_FOUND);
            
            self.group_admins.read(group_id)
        }

        fn is_group_member(self: @ContractState, group_id: felt252, address: ContractAddress) -> bool {
            // Ensure group exists
            assert(self.group_metadata.read(group_id) != 0, ERROR_GROUP_NOT_FOUND);
            
            self.group_members.read((group_id, address))
        }

        fn get_members_count(self: @ContractState, group_id: felt252) -> u32 {
            // Ensure group exists
            assert(self.group_metadata.read(group_id) != 0, ERROR_GROUP_NOT_FOUND);
            
            self.group_members_count.read(group_id)
        }

        fn is_user_in_group(self: @ContractState, user: ContractAddress, group_id: felt252) -> bool {
            // This is a convenience function for querying from the member's perspective
            self.member_groups.read((user, group_id))
        }
    }
}
