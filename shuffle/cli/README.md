# Experimental

## Step 0: Install Dependencies

- Install Diem dependencies including Rust, Clang, etc, by running the following script in `diem` root directory:
```
./scripts/dev_setup.sh
cargo install --path shuffle/cli 
brew install deno
```

## Usage

Please run `shuffle help`.

## Sample Usage

From the `diem/` base repo directory:

1. `cargo run -p shuffle -- new <directory>` creates a new shuffle project. Example:`cargo run -p shuffle -- new /tmp/helloblockchain`
2. `cargo run -p shuffle -- node` runs node based on project, perform in a different terminal
3. `cargo run -p shuffle -- account` creates a dev and test account onchain
4. `cargo run -p shuffle -- deploy -p <directory>` publishes a module to the created node. You can also enter the project directory with Shuffle.toml and run `cargo run -p shuffle -- deploy` 
5. `cargo run -p shuffle -- console -p <directory>` enters a typescript REPL with helpers loaded. You can also enter the project directory with Shuffle.toml and run `cargo run -p shuffle -- console`
6. `cargo run -p shuffle -- test -p <directory>` runs end to end tests. You can also enter the project directory with Shuffle.toml and run `cargo run -p shuffle -- test`


## Development

Note that for local development, `shuffle` is replaced with `cargo run -p shuffle --`:

```bash
shuffle new /tmp/helloblockchain # is replaced by
cargo run -p shuffle -- new /tmp/helloblockchain
```
