/// Maintains information about the set of validators used during consensus.
/// Provides functions to add, remove, and update validators in the
/// validator set.
///
/// > Note: When trying to understand this code, it's important to know that "config"
/// and "configuration" are used for several distinct concepts.
module ExperimentalFramework::DiemSystem {
    use ExperimentalFramework::DiemConfig::{Self, ModifyConfigCapability};
    use ExperimentalFramework::ValidatorConfig;
    use CoreFramework::SystemAddresses;
    use CoreFramework::DiemTimestamp;
    use Std::Errors;
    use Std::Option::{Self, Option};
    use Std::Signer;
    use Std::Vector;

    /// Information about a Validator Owner.
    struct ValidatorInfo has copy, drop, store {
        /// The address (account) of the Validator Owner
        addr: address,
        /// The voting power of the Validator Owner (currently always 1).
        consensus_voting_power: u64,
        /// Configuration information about the Validator, such as the
        /// Validator Operator, human name, and info such as consensus key
        /// and network addresses.
        config: ValidatorConfig::Config,
        /// The time of last reconfiguration invoked by this validator
        /// in microseconds
        last_config_update_time: u64,
    }

    /// Enables a scheme that restricts the DiemSystem config
    /// in DiemConfig from being modified by any other module.  Only
    /// code in this module can get a reference to the ModifyConfigCapability<DiemSystem>,
    /// which is required by `DiemConfig::set_with_capability_and_reconfigure` to
    /// modify the DiemSystem config. This is only needed by `update_config_and_reconfigure`.
    /// Only Diem root can add or remove a validator from the validator set, so the
    /// capability is not needed for access control in those functions.
    struct CapabilityHolder has key {
        /// Holds a capability returned by `DiemConfig::publish_new_config_and_get_capability`
        /// which is called in `initialize_validator_set`.
        cap: ModifyConfigCapability<DiemSystem>,
    }

    /// The DiemSystem struct stores the validator set and crypto scheme in
    /// DiemConfig. The DiemSystem struct is stored by DiemConfig, which publishes a
    /// DiemConfig<DiemSystem> resource.
    struct DiemSystem has copy, drop, store {
        /// The current consensus crypto scheme.
        scheme: u8,
        /// The current validator set.
        validators: vector<ValidatorInfo>,
    }

    /// The `CapabilityHolder` resource was not in the required state
    const ECAPABILITY_HOLDER: u64 = 0;
    /// Tried to add a validator with an invalid state to the validator set
    const EINVALID_PROSPECTIVE_VALIDATOR: u64 = 1;
    /// Tried to add a validator to the validator set that was already in it
    const EALREADY_A_VALIDATOR: u64 = 2;
    /// An operation was attempted on an address not in the vaidator set
    const ENOT_AN_ACTIVE_VALIDATOR: u64 = 3;
    /// The validator operator is not the operator for the specified validator
    const EINVALID_TRANSACTION_SENDER: u64 = 4;
    /// An out of bounds index for the validator set was encountered
    const EVALIDATOR_INDEX: u64 = 5;
    /// Rate limited when trying to update config
    const ECONFIG_UPDATE_RATE_LIMITED: u64 = 6;
    /// Validator set already at maximum allowed size
    const EMAX_VALIDATORS: u64 = 7;
    /// Validator config update time overflows
    const ECONFIG_UPDATE_TIME_OVERFLOWS: u64 = 8;

    /// Number of microseconds in 5 minutes
    const FIVE_MINUTES: u64 = 300000000;

    /// The maximum number of allowed validators in the validator set
    const MAX_VALIDATORS: u64 = 256;

    /// The largest possible u64 value
    const MAX_U64: u64 = 18446744073709551615;

    ///////////////////////////////////////////////////////////////////////////
    // Setup methods
    ///////////////////////////////////////////////////////////////////////////


    /// Publishes the DiemConfig for the DiemSystem struct, which contains the current
    /// validator set. Also publishes the `CapabilityHolder` with the
    /// ModifyConfigCapability<DiemSystem> returned by the publish function, which allows
    /// code in this module to change DiemSystem config (including the validator set).
    /// Must be invoked by the Diem root a single time in Genesis.
    public fun initialize_validator_set(
        dr_account: &signer,
    ) {
        DiemTimestamp::assert_genesis();
        SystemAddresses::assert_core_resource(dr_account);

        let cap = DiemConfig::publish_new_config_and_get_capability<DiemSystem>(
            dr_account,
            DiemSystem {
                scheme: 0,
                validators: Vector::empty(),
            },
        );
        assert!(
            !exists<CapabilityHolder>(@DiemRoot),
            Errors::already_published(ECAPABILITY_HOLDER)
        );
        move_to(dr_account, CapabilityHolder { cap })
    }

    /// Copies a DiemSystem struct into the DiemConfig<DiemSystem> resource
    /// Called by the add, remove, and update functions.
    fun set_diem_system_config(value: DiemSystem) acquires CapabilityHolder {
        DiemTimestamp::assert_operating();
        assert!(
            exists<CapabilityHolder>(@DiemRoot),
            Errors::not_published(ECAPABILITY_HOLDER)
        );
        // Updates the DiemConfig<DiemSystem> and emits a reconfigure event.
        DiemConfig::set_with_capability_and_reconfigure<DiemSystem>(
            &borrow_global<CapabilityHolder>(@DiemRoot).cap,
            value
        )
    }

    ///////////////////////////////////////////////////////////////////////////
    // Methods operating the Validator Set config callable by the diem root account
    ///////////////////////////////////////////////////////////////////////////

    /// Adds a new validator to the validator set.
    public fun add_validator(
        dr_account: &signer,
        validator_addr: address
    ) acquires CapabilityHolder {
        DiemTimestamp::assert_operating();
        SystemAddresses::assert_core_resource(dr_account);

        // A prospective validator must have a validator config resource
        assert!(
            ValidatorConfig::is_valid(validator_addr),
            Errors::invalid_argument(EINVALID_PROSPECTIVE_VALIDATOR)
        );

        // Bound the validator set size
        assert!(
            validator_set_size() < MAX_VALIDATORS,
            Errors::limit_exceeded(EMAX_VALIDATORS)
        );

        let diem_system_config = get_diem_system_config();

        // Ensure that this address is not already a validator
        assert!(
            !is_validator_(validator_addr, &diem_system_config.validators),
            Errors::invalid_argument(EALREADY_A_VALIDATOR)
        );

        // it is guaranteed that the config is non-empty
        let config = ValidatorConfig::get_config(validator_addr);
        Vector::push_back(&mut diem_system_config.validators, ValidatorInfo {
            addr: validator_addr,
            config, // copy the config over to ValidatorSet
            consensus_voting_power: 1,
            last_config_update_time: DiemTimestamp::now_microseconds(),
        });

        set_diem_system_config(diem_system_config);
    }

    /// Removes a validator, aborts unless called by diem root account
    public fun remove_validator(
        dr_account: &signer,
        validator_addr: address
    ) acquires CapabilityHolder {
        DiemTimestamp::assert_operating();
        SystemAddresses::assert_core_resource(dr_account);
        let diem_system_config = get_diem_system_config();
        // Ensure that this address is an active validator
        let to_remove_index_vec = get_validator_index_(&diem_system_config.validators, validator_addr);
        assert!(Option::is_some(&to_remove_index_vec), Errors::invalid_argument(ENOT_AN_ACTIVE_VALIDATOR));
        let to_remove_index = *Option::borrow(&to_remove_index_vec);
        // Remove corresponding ValidatorInfo from the validator set
        _  = Vector::swap_remove(&mut diem_system_config.validators, to_remove_index);

        set_diem_system_config(diem_system_config);
    }

    /// Copy the information from ValidatorConfig into the validator set.
    /// This function makes no changes to the size or the members of the set.
    /// If the config in the ValidatorSet changes, it stores the new DiemSystem
    /// and emits a reconfigurationevent.
    public fun update_config_and_reconfigure(
        validator_operator_account: &signer,
        validator_addr: address,
    ) acquires CapabilityHolder {
        DiemTimestamp::assert_operating();
        assert!(
            ValidatorConfig::get_operator(validator_addr) == Signer::address_of(validator_operator_account),
            Errors::invalid_argument(EINVALID_TRANSACTION_SENDER)
        );
        let diem_system_config = get_diem_system_config();
        let to_update_index_vec = get_validator_index_(&diem_system_config.validators, validator_addr);
        assert!(Option::is_some(&to_update_index_vec), Errors::invalid_argument(ENOT_AN_ACTIVE_VALIDATOR));
        let to_update_index = *Option::borrow(&to_update_index_vec);
        let is_validator_info_updated = update_ith_validator_info_(&mut diem_system_config.validators, to_update_index);
        if (is_validator_info_updated) {
            let validator_info = Vector::borrow_mut(&mut diem_system_config.validators, to_update_index);
            assert!(
                validator_info.last_config_update_time <= MAX_U64 - FIVE_MINUTES,
                Errors::limit_exceeded(ECONFIG_UPDATE_TIME_OVERFLOWS)
            );
            assert!(
                DiemTimestamp::now_microseconds() > validator_info.last_config_update_time + FIVE_MINUTES,
                Errors::limit_exceeded(ECONFIG_UPDATE_RATE_LIMITED)
            );
            validator_info.last_config_update_time = DiemTimestamp::now_microseconds();
            set_diem_system_config(diem_system_config);
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    // Publicly callable APIs: getters
    ///////////////////////////////////////////////////////////////////////////

    /// Get the DiemSystem configuration from DiemConfig
    public fun get_diem_system_config(): DiemSystem {
        DiemConfig::get<DiemSystem>()
    }

    /// Return true if `addr` is in the current validator set
    public fun is_validator(addr: address): bool {
        is_validator_(addr, &get_diem_system_config().validators)
    }

    /// Returns validator config. Aborts if `addr` is not in the validator set.
    public fun get_validator_config(addr: address): ValidatorConfig::Config {
        let diem_system_config = get_diem_system_config();
        let validator_index_vec = get_validator_index_(&diem_system_config.validators, addr);
        assert!(Option::is_some(&validator_index_vec), Errors::invalid_argument(ENOT_AN_ACTIVE_VALIDATOR));
        *&(Vector::borrow(&diem_system_config.validators, *Option::borrow(&validator_index_vec))).config
    }

    /// Return the size of the current validator set
    public fun validator_set_size(): u64 {
        Vector::length(&get_diem_system_config().validators)
    }

    /// Get the `i`'th validator address in the validator set.
    public fun get_ith_validator_address(i: u64): address {
        assert!(i < validator_set_size(), Errors::invalid_argument(EVALIDATOR_INDEX));
        Vector::borrow(&get_diem_system_config().validators, i).addr
    }

    ///////////////////////////////////////////////////////////////////////////
    // Private functions
    ///////////////////////////////////////////////////////////////////////////

    /// Get the index of the validator by address in the `validators` vector
    /// It has a loop, so there are spec blocks in the code to assert loop invariants.
    fun get_validator_index_(validators: &vector<ValidatorInfo>, addr: address): Option<u64> {
        let size = Vector::length(validators);
        let i = 0;
        while (i < size) {
            let validator_info_ref = Vector::borrow(validators, i);
            if (validator_info_ref.addr == addr) {
                return Option::some(i)
            };
            i = i + 1;
        };
        return Option::none()
    }

    /// Updates *i*th validator info, if nothing changed, return false.
    /// This function never aborts.
    fun update_ith_validator_info_(validators: &mut vector<ValidatorInfo>, i: u64): bool {
        let size = Vector::length(validators);
        // This provably cannot happen, but left it here for safety.
        if (i >= size) {
            return false
        };
        let validator_info = Vector::borrow_mut(validators, i);
        // "is_valid" below should always hold based on a global invariant later
        // in the file (which proves if we comment out some other specifications),
        // but it is left here for safety.
        if (!ValidatorConfig::is_valid(validator_info.addr)) {
            return false
        };
        let new_validator_config = ValidatorConfig::get_config(validator_info.addr);
        // check if information is the same
        let config_ref = &mut validator_info.config;
        if (config_ref == &new_validator_config) {
            return false
        };
        *config_ref = new_validator_config;
        true
    }

    /// Private function checks for membership of `addr` in validator set.
    fun is_validator_(addr: address, validators_vec_ref: &vector<ValidatorInfo>): bool {
        Option::is_some(&get_validator_index_(validators_vec_ref, addr))
    }
}
