module Sender::IntegrationTest {
    use Std::ASCII;
    use Std::Signer;
    use Std::Vector;
    #[test_only]
    use Std::UnitTest;

    struct ContentHolder has key {
        strings: vector<ASCII::String>,
        numbers: vector<u64>,
    }

    public(script) fun write_vectors(account: signer, numbers: vector<u64>, strings: vector<vector<u8>>)
    acquires ContentHolder {
      write_vectors_impl(account, numbers, strings)
    }

    public fun write_vectors_impl(account: signer, numbers: vector<u64>, strings: vector<vector<u8>>)
    acquires ContentHolder {
        // normalize strings (vec<vec<u8>>) into vec<ASCII::String> type
        let i = 0;
        let len = Vector::length(&strings);
        let normalized_strings = Vector::empty<ASCII::String>();
        while (i < len) {
            let ascii_bytes = *Vector::borrow(&strings, i);
            Vector::push_back(
                &mut normalized_strings,
                ASCII::string(ascii_bytes),
            );
            i = i + 1;
        };

        // initialize resource in account if it doesn't exist
        let account_addr = Signer::address_of(&account);
        if (!exists<ContentHolder>(account_addr)) {
            move_to(&account, ContentHolder {
                strings: Vector::empty<ASCII::String>(),
                numbers: Vector::empty<u64>(),
            });
        };

        // save new content in account
        let content_holder = borrow_global_mut<ContentHolder>(account_addr);
        content_holder.strings = normalized_strings;
        content_holder.numbers = numbers;
    }

    #[test]
    fun test_write_vector() acquires ContentHolder {
        let account = get_account();
        let addr = Signer::address_of(&account);
        let numbers: vector<u64> = vector[1, 2];
        let strings: vector<vector<u8>> = vector[b"hello", b"world"];
         
        write_vectors_impl(account, *&numbers, strings);
        let content_holder = borrow_global<ContentHolder>(addr);
        let expected_strings = vector[
            ASCII::string(b"hello"),
            ASCII::string(b"world")
        ];

        assert!(*&content_holder.numbers == numbers, 0);
        assert!(*&content_holder.strings == expected_strings, 0);
    }

    #[test_only]
    fun get_account(): signer {
        Vector::pop_back(&mut UnitTest::create_signers_for_testing(1))
    }
}
