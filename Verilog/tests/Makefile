# Meta-checks over the test suite itself.
#
# test-tb-catalog: every testbench in the tree is either reached by
# run_all_tests.sh or explicitly baselined in tb_catalog.py with a reason.
# Catches the drift where a testbench is written, works, and is then never
# run again because nobody added it to the registry.

test-tb-catalog:
	python3 tb_catalog.py --check

catalog:
	python3 tb_catalog.py

.PHONY: test-tb-catalog catalog
