# ── AI Company Landscape — Google Sheet Management ──
# Uses gws CLI (https://github.com/EvolvingLMMs-Lab/gws) to manage sheet data.
# Run `make help` for usage.

SHEET_ID := 1kP3_XXgEXrONawXUnlo5KR94CV5mNFVhtd41Zk-_GYE
TAB      := Claude Research
RANGE    := $(TAB)
HTML     := ai-landscape.html

# Column letters: A=category B=category_color C=category_icon D=company
#                 E=overall_revenue_B F=pure_ai_revenue_B G=pure_play H=note I=url

.PHONY: help check-auth list list-table list-csv count categories \
        find find-row add update update-revenue update-row delete bulk-add sync-fallback

# ── Help ──────────────────────────────────────────────────────────────────────

help: ## Show all targets with examples
	@echo "AI Company Landscape — Sheet Management"
	@echo ""
	@echo "Setup:"
	@echo "  gws auth login -s sheets    # one-time OAuth login"
	@echo ""
	@echo "Targets:"
	@echo "  make check-auth              Verify gws authentication"
	@echo "  make list                    List all companies (JSON)"
	@echo "  make list-table              List all companies (table)"
	@echo "  make list-csv                List all companies (CSV)"
	@echo "  make count                   Count total companies"
	@echo "  make categories              List unique categories"
	@echo '  make find COMPANY="OpenAI"   Search by company name'
	@echo '  make find-row COMPANY="OpenAI"  Get row number for a company'
	@echo ""
	@echo "  make add COMPANY=\"Acme\" CATEGORY=\"Enterprise AI\" COLOR=\"#2dd4bf\" ICON=\"🏢\" \\"
	@echo "           REVENUE=1.5 AI_REVENUE=0.8 PURE_PLAY=TRUE NOTE=\"Series B\""
	@echo "  make update ROW=5 COL=E VALUE=\"13.0\""
	@echo "  make update-revenue ROW=5 REVENUE=13.0 AI_REVENUE=11.6"
	@echo '  make update-row ROW=5 COMPANY="OpenAI" CATEGORY="Foundation Models" \'
	@echo '       COLOR="#a78bfa" ICON="🧠" REVENUE=13.0 AI_REVENUE=11.6 PURE_PLAY=TRUE NOTE="Updated"'
	@echo "  make delete ROW=42"
	@echo "  make bulk-add FILE=new.csv"
	@echo ""
	@echo "  make sync-fallback           Sync sheet into FALLBACK_DATA in HTML"

# ── Auth ──────────────────────────────────────────────────────────────────────

check-auth: ## Verify gws is authenticated
	@gws sheets +read --spreadsheet "$(SHEET_ID)" --range "'$(TAB)'!A1:A1" --format csv > /dev/null 2>&1 \
		&& echo "✓ Authenticated — gws can read the sheet" \
		|| (echo "✗ Not authenticated. Run: gws auth login -s sheets" && exit 1)

# ── Read ──────────────────────────────────────────────────────────────────────

list: ## List all companies (JSON)
	@gws sheets +read --spreadsheet "$(SHEET_ID)" --range "'$(TAB)'" --format json

list-table: ## List all companies (table)
	@gws sheets +read --spreadsheet "$(SHEET_ID)" --range "'$(TAB)'" --format table

list-csv: ## List all companies (CSV)
	@gws sheets +read --spreadsheet "$(SHEET_ID)" --range "'$(TAB)'" --format csv

count: ## Count total companies (excludes header)
	@gws sheets +read --spreadsheet "$(SHEET_ID)" --range "'$(TAB)'" --format csv \
		| tail -n +2 | grep -c . || echo "0"

categories: ## List unique categories
	@gws sheets +read --spreadsheet "$(SHEET_ID)" --range "'$(TAB)'!B:B" --format csv \
		| tail -n +2 | sort -u

# ── Search ────────────────────────────────────────────────────────────────────

find: ## Search by company name (COMPANY="...")
ifndef COMPANY
	$(error COMPANY is required. Usage: make find COMPANY="OpenAI")
endif
	@gws sheets +read --spreadsheet "$(SHEET_ID)" --range "'$(TAB)'" --format csv \
		| grep -i "$(COMPANY)" || echo "No matches for '$(COMPANY)'"

find-row: ## Get row number for a company (COMPANY="...")
ifndef COMPANY
	$(error COMPANY is required. Usage: make find-row COMPANY="OpenAI")
endif
	@gws sheets +read --spreadsheet "$(SHEET_ID)" --range "'$(TAB)'" --format csv \
		| grep -in "$(COMPANY)" | while IFS=: read -r num line; do \
			echo "Row $$num: $$line"; \
		done || echo "No matches for '$(COMPANY)'"

# ── Write ─────────────────────────────────────────────────────────────────────

add: ## Add a new company
ifndef COMPANY
	$(error COMPANY is required)
endif
ifndef CATEGORY
	$(error CATEGORY is required)
endif
	@gws sheets +append --spreadsheet "$(SHEET_ID)" \
		--values '$(COMPANY),$(CATEGORY),$(or $(COLOR),),$(or $(ICON),),$(or $(REVENUE),),$(or $(AI_REVENUE),),$(or $(PURE_PLAY),),$(or $(NOTE),)'
	@echo "✓ Added $(COMPANY)"

update: ## Update a single cell (ROW=, COL=, VALUE=)
ifndef ROW
	$(error ROW is required. Usage: make update ROW=5 COL=E VALUE="13.0")
endif
ifndef COL
	$(error COL is required (A-H). Usage: make update ROW=5 COL=E VALUE="13.0")
endif
ifndef VALUE
	$(error VALUE is required. Usage: make update ROW=5 COL=E VALUE="13.0")
endif
	@gws sheets spreadsheets values update \
		--params '{"spreadsheetId":"$(SHEET_ID)","range":"'"'"'$(TAB)'"'"'!$(COL)$(ROW)","valueInputOption":"USER_ENTERED"}' \
		--json '{"values":[["$(VALUE)"]]}'
	@echo "✓ Updated $(TAB)!$(COL)$(ROW) = $(VALUE)"

update-revenue: ## Update revenue columns E+F (ROW=, REVENUE=, AI_REVENUE=)
ifndef ROW
	$(error ROW is required)
endif
ifndef REVENUE
	$(error REVENUE is required)
endif
ifndef AI_REVENUE
	$(error AI_REVENUE is required)
endif
	@gws sheets spreadsheets values update \
		--params '{"spreadsheetId":"$(SHEET_ID)","range":"'"'"'$(TAB)'"'"'!E$(ROW):F$(ROW)","valueInputOption":"USER_ENTERED"}' \
		--json '{"values":[["$(REVENUE)","$(AI_REVENUE)"]]}'
	@echo "✓ Updated row $(ROW) revenue: $(REVENUE)B overall, $(AI_REVENUE)B AI"

update-row: ## Update an entire row (ROW=, COMPANY=, CATEGORY=, COLOR=, ICON=, REVENUE=, AI_REVENUE=, PURE_PLAY=, NOTE=)
ifndef ROW
	$(error ROW is required)
endif
ifndef COMPANY
	$(error COMPANY is required)
endif
	@gws sheets spreadsheets values update \
		--params '{"spreadsheetId":"$(SHEET_ID)","range":"'"'"'$(TAB)'"'"'!A$(ROW):H$(ROW)","valueInputOption":"USER_ENTERED"}' \
		--json '{"values":[["$(COMPANY)","$(or $(CATEGORY),)","$(or $(COLOR),)","$(or $(ICON),)","$(or $(REVENUE),)","$(or $(AI_REVENUE),)","$(or $(PURE_PLAY),)","$(or $(NOTE),)"]]}'
	@echo "✓ Updated row $(ROW)"

delete: ## Clear a row with confirmation (ROW=)
ifndef ROW
	$(error ROW is required. Usage: make delete ROW=42)
endif
	@printf "About to clear row $(ROW). Continue? [y/N] " && read ans && [ "$${ans:-N}" = "y" ] || (echo "Cancelled" && exit 1)
	@gws sheets spreadsheets values clear \
		--params '{"spreadsheetId":"$(SHEET_ID)","range":"'"'"'$(TAB)'"'"'!A$(ROW):H$(ROW)"}'
	@echo "✓ Cleared row $(ROW)"

# ── Bulk ──────────────────────────────────────────────────────────────────────

bulk-add: ## Bulk add companies from CSV file (FILE=)
ifndef FILE
	$(error FILE is required. Usage: make bulk-add FILE=new.csv)
endif
	@if [ ! -f "$(FILE)" ]; then echo "ERROR: $(FILE) not found" && exit 1; fi
	@echo "Adding companies from $(FILE)..."
	@JSON_ROWS=$$(python3 -c "\
import csv, json, sys; \
rows = []; \
reader = csv.reader(open(sys.argv[1])); \
header = next(reader, None); \
for r in reader: rows.append(r[:8]); \
print(json.dumps(rows))" "$(FILE)") && \
	gws sheets +append --spreadsheet "$(SHEET_ID)" --json-values "$$JSON_ROWS"
	@echo "✓ Bulk add complete"

# ── Sync ──────────────────────────────────────────────────────────────────────

sync-fallback: ## Sync sheet data into FALLBACK_DATA in ai-landscape.html
	@SHEET_ID="$(SHEET_ID)" TAB="'$(TAB)'" HTML="$(HTML)" \
		bash scripts/sync-fallback.sh
