# COBOL Core Banking System

> **Personal project / learning exercise.** This is not production
> software, has never been used by a bank, and must not be used to hold
> real customer data or real money. All sample data is fictional.

A small but complete core banking back end written in COBOL for
GnuCOBOL 3.x. It covers customers, savings and current accounts,
deposits, withdrawals, internal transfers, reversals, an append-only
transaction ledger, an audit trail, end-of-day batch processing,
reports, an interactive teller menu, a command-line interface for
scripts, and an automated test suite.

The aim is to show how a classic mainframe-style system is structured
(copybooks, layered subprograms, fixed-format records, batch jobs,
status codes), running entirely on a laptop with indexed and
line-sequential files.

## Features

- **Customers**: create, look up, and validate (ID format, name, phone,
  email, date of birth). Duplicate IDs are rejected.
- **Accounts**: SAV (savings) and CUR (current). Accounts can be
  active, inactive or blocked. Each has a currency from a configured
  list. Current accounts may have an overdraft up to a configured
  maximum; savings accounts never go below zero.
- **Money movement**: deposits, withdrawals and internal transfers,
  all through one posting engine (`TXN-POST`).
  - Transfers are all-or-nothing. If any step fails, changes are
    rolled back by compensation, and this is covered by
    fault-injection tests.
  - Transfers between different currencies are rejected.
- **Reversals**: a posted transaction can be reversed by a new
  REVERSAL entry. The original is never edited, and double reversal
  or reversing a reversal is rejected.
- **Ledger**: append-only, human-readable journal. Transaction IDs are
  unique and strictly increasing (`TXN` + 12 digits).
- **Audit trail**: every create, status change, financial operation
  (success or failure), batch run and daily run is recorded. It holds
  no customer contact data.
- **Status codes**: 000 and 101–110, defined in one place
  (`copybooks/STATUSCD.cpy` and the `CBS-STATUS` module).
- **Batch**:
  - `BATCH-POST` posts a pipe-delimited instruction file. Malformed
    lines are rejected, audited and skipped; one bad line never stops
    a run.
  - `DAILY-PROCESS` produces the end-of-day report. It shows counts
    and values per transaction type, and exceptions: malformed ledger
    lines, rejected operations and large transactions.
- **Reports**: account transaction history, customer account summary
  (contact data masked), daily totals, and failed transactions.
- **Interfaces**: an interactive menu (`bin/cbs`) and a scriptable CLI
  (`bin/cbs-cli`) with scheduler-friendly return codes.
- **Tests**: 9 COBOL test suites plus CLI smoke tests, run by
  `tests/run_tests.sh`.

## Architecture

```
 bin/cbs (CBSMAIN)        bin/cbs-cli (CBSCLI)          presentation
        |                        |
        |            BATCH-POST  DAILY-PROCESS          batch
        |                 |           |
        v                 v           v
 CUSTOMER-CREATE/LOOKUP  ACCOUNT-CREATE/LOOKUP/UPDATE   services
 TXN-DEPOSIT  TXN-WITHDRAW  TXN-TRANSFER  TXN-REVERSE
                    \        |        /
                     TXN-POST (posting engine)
                            |
 ID-/CUSTOMER-/ACCOUNT-/TXN-VALIDATE, AMOUNT-PARSE      validation
                            |
 CUSTOMER-DAO ACCOUNT-DAO LEDGER-DAO AUDIT-DAO SEQUENCE-DAO  persistence
                            |
 customers.dat  accounts.dat  transactions.dat  audit.log  txn-sequence.dat
```

- Presentation code holds no business rules.
- Business rules live in the validation and service layers.
- Only the `*-DAO` modules touch files, so the storage could be
  replaced by a database without changing the services.

See [docs/architecture.md](docs/architecture.md) for details.

## Prerequisites

- GnuCOBOL 3.x (`cobc`), built with indexed-file support (BDB or
  VBISAM). Developed and tested with GnuCOBOL 3.1.2 on Ubuntu 24.04.
  - Debian/Ubuntu: `sudo apt-get install gnucobol`
  - macOS (Homebrew): `brew install gnucobol`
- `bash` and standard POSIX tools (`make` is optional).

## Install and build

```bash
git clone <this-repo> cobol-core-banking   # or unzip the archive
cd cobol-core-banking
./scripts/build.sh          # or: make build
```

The build first checks that every source line fits in columns 1–72.
It then compiles every module with `-Wall` and links `bin/cbs` and
`bin/cbs-cli`. Any compile or link error stops the build with a
non-zero exit code.

## Run

```bash
./scripts/reset-data.sh     # load the fictional seed data (make reset)
./scripts/run.sh            # interactive teller menu      (make run)
```

`run.sh` loads the seed data automatically the first time, when no
data exists yet. You are asked for an operator ID (for example
`TELLER01`), which is recorded in the ledger and audit trail. Then the
menu appears:

```
=== COBOL CORE BANKING SYSTEM ===
 1. Create Customer         8. Account Transaction History
 2. Find Customer           9. Daily Report
 3. Create Account         10. Exit
 4. Find Account           11. Customer Account Summary
 5. Deposit                12. Failed Transaction Report
 6. Withdraw               13. Reverse Transaction
 7. Transfer               14. Change Account Status
```

Seed accounts to try:

| Account | Type | Details |
|---|---|---|
| 1000000001 | SAV USD | Customer C0000001 |
| 1000000002 | CUR USD | Same customer, 1,000 overdraft |
| 1000000005 | SAV EUR | For a currency-mismatch test |
| 1000000011 | CUR USD | Blocked |

## Test

```bash
./tests/run_tests.sh        # or: make test   (-v shows every check)
```

The runner builds the test drivers and runs each suite against its own
temporary data directory, so your `./data` is never touched. It prints
one line per suite and a total, and exits 0 only when every check
passed:

```
Customer Tests .............. PASS (26 checks)
...
TOTAL: 227
PASSED: 227
FAILED: 0
```

See [docs/testing.md](docs/testing.md).

## Reports and batch

```bash
./scripts/report.sh daily [YYYYMMDD]      # daily banking report
./scripts/report.sh history 1000000001    # account history
./scripts/report.sh summary C0000001      # customer summary
./scripts/report.sh failed [YYYYMMDD|ALL] # failed transactions
./bin/cbs-cli post my-batch.txt           # post a batch file
./batch/run-daily.sh [YYYYMMDD] [file]    # end-of-day job (make daily)
```

Reports are written to `reports/`. CLI return codes:

| Code | Meaning |
|---|---|
| 0 | OK |
| 4 | Batch completed with rejected lines |
| 8 | Business error |
| 12 | Storage error |
| 16 | Usage error |

See [docs/operations.md](docs/operations.md).

## Project structure

```
copybooks/          shared record layouts, request blocks, status codes
src/persistence/    *-DAO modules - the only code that does file I/O
src/validation/     ID, customer, account, transaction, amount, ledger checks
src/services/       customer/account services, posting engine, txn services
src/reporting/      report generators and report printer
src/programs/       CBSMAIN (menu) and CBSCLI (command line)
batch/              BATCH-POST, DAILY-PROCESS, run-daily.sh
config/cbs.conf     bank name, currencies, limits
data/seed/          fictional seed data and deliberate-failure sample
data/sample/        sample ledger and audit log produced from the seed
reports/            generated reports (git-ignored content)
scripts/            build.sh run.sh reset-data.sh report.sh common.sh
tests/              run_tests.sh, suites/ (COBOL drivers), copybooks/,
                    fixtures/
docs/               architecture, business rules, data model,
                    operations, testing
```

## Example workflows

**Open an account and move money.** In the menu:
1. Create a customer with option 1.
2. Open a SAV and a CUR account with option 3.
3. Deposit with option 5, then withdraw with option 6.
4. Transfer between the two accounts with option 7.
5. Check balances with option 4, and print the history with option 8.

**Correct a mistake.** Find the transaction ID in the account history
(option 8), then reverse it with option 13. The original entry stays
in the ledger; a REVERSAL entry restores the balance.

**End of day.** Run `./batch/run-daily.sh`. Then check the exception
section of `reports/daily-report-<date>.txt` and the failed
transaction report.

## Limitations

This is a teaching-sized system:
- There is no authentication: the operator ID is self-declared.
- It is single-user with no record locking.
- Transfers are made atomic by compensating updates, not by a real
  transaction manager or write-ahead log, so a process crash between
  file writes needs manual repair.
- Reports scan files sequentially.
- There is no interest, fees, holds, statements, FX or multi-branch
  support.
- Names are ASCII only.

The full list, with what a production system would need instead, is
in [docs/architecture.md](docs/architecture.md#limitations).

## Future improvements

- Store data in a relational database through the existing DAO layer,
  with real transactions.
- Add operator authentication and roles (for example, reversals and
  blocking restricted to supervisors).
- Add record locking or a single posting server for concurrent use.
- Add interest accrual, fees and statement generation as batch jobs.
- Add pending holds (available balance different from ledger balance).
- Index the ledger by account to speed up history and reversal lookup.
- Run CI on every push.

## License

MIT - see [LICENSE](LICENSE).
# cobol_system_I
