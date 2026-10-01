# ================================================================
# Makefile - convenience targets; all logic lives in scripts/.
# ================================================================
.PHONY: all build test run reset reset-empty daily clean help

all: build

build:            ## compile all modules and link bin/cbs, bin/cbs-cli
	./scripts/build.sh

test:             ## build incl. test drivers and run all suites
	./tests/run_tests.sh

run: build        ## start the interactive teller menu
	./scripts/run.sh

reset: build      ## wipe ./data and reload seed + sample exceptions
	./scripts/reset-data.sh

reset-empty: build ## wipe ./data, leave the system empty
	./scripts/reset-data.sh --empty

daily: build      ## end-of-day job for today (DATE=YYYYMMDD optional)
	./batch/run-daily.sh $(DATE)

clean:            ## remove build output and generated reports
	rm -rf bin/obj bin/tests bin/cbs bin/cbs-cli
	find reports -maxdepth 1 -name '*.txt' -delete

help:
	@grep -E '^[a-z-]+:.*## ' Makefile | \
	  awk -F':.*## ' '{printf "  make %-12s %s\n", $$1, $$2}'
