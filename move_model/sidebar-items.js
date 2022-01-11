initSidebarItems({"fn":[["addr_to_big_uint","Converts an address identifier to a number representing the address."],["big_uint_to_addr","Converts a biguint into an account address"],["parse_addresses_from_options",""],["run_bytecode_model_builder","Build a `GlobalEnv` from a collection of `CompiledModule`’s. The `modules` list must be topologically sorted by the dependency relation (i.e., a child node in the dependency graph should appear earlier in the vector than its parents)."],["run_model_builder","Build the move model with default compilation flags and default options and no named addresses. This collects transitive dependencies for move sources from the provided directory list."],["run_model_builder_with_options","Build the move model with default compilation flags and custom options and a set of provided named addreses. This collects transitive dependencies for move sources from the provided directory list."],["run_model_builder_with_options_and_compilation_flags","Build the move model with custom compilation flags and custom options This collects transitive dependencies for move sources from the provided directory list."]],"macro":[["emit","Macro to emit a simple or formatted string."],["emitln","Macro to emit a simple or formatted string followed by a new line."]],"mod":[["ast","Contains AST definitions for the specification language fragments of the Move language. Note that in this crate, specs are represented in AST form, whereas code is represented as bytecodes. Therefore we do not need an AST for the Move code itself."],["code_writer","A helper for generating structured code."],["exp_generator",""],["exp_rewriter",""],["model","Provides a model for a set of Move modules (and scripts, which are handled like modules). The model allows to access many different aspects of the Move code: all declared functions and types, their associated bytecode, their source location, their source text, and the specification fragments."],["native","Contains constants for well-known names of native functions"],["options",""],["pragmas","Provides pragmas and properties of the specification language."],["simplifier",""],["spec_translator","This module supports translations of specifications as found in the move-model to expressions which can be used in assumes/asserts in bytecode."],["symbol","Contains definitions of symbols – internalized strings which support fast hashing and comparison."],["ty","Contains types and related functions."]]});