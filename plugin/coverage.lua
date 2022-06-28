local M = {}

local mark = vim.api.nvim_buf_set_extmark

local group = vim.api.nvim_create_augroup("UserCoverage", { clear = true })
local ns = vim.api.nvim_create_namespace("UserCoverage")

local function find_coverage_file()
	local path = vim.fn.findfile("coverage/coverage-final.json", ".;")

	if path == "" then
		return false
	end

	return vim.fn.fnamemodify(path, ":p")
end

local function get_coverage(file)
	local f = io.open(file, "r")
	local buff = f:read("*a")
	f:close()

	return vim.json.decode(buff)
end

local function safe_num(v)
	if v == vim.NIL then
		return 0
	end

	return v
end

local function mkloc(t)
	return { safe_num(t.line) - 1, safe_num(t.column) }
end

local function to_sign_text(value)
	if value > 99 then
		return "+N"
	end

	return tostring(value)
end

local function apply_coverage()
	vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

	local buf = vim.api.nvim_get_current_buf()
	local current_file = vim.api.nvim_buf_get_name(buf)
	current_file = vim.fn.fnamemodify(current_file, ":p")

	local coverage_file = find_coverage_file()

	if not coverage_file then
		return
	end

	local coverage = get_coverage(coverage_file)

	local file_cov = coverage[current_file]

	if not file_cov then
		return
	end

	local statement_map = file_cov.statementMap
	local branch_map = file_cov.branchMap
	local fn_map = file_cov.fnMap

	for key, value in pairs(file_cov.f) do
		local fn = fn_map[key]
		local s = mkloc(fn.decl.start)
		local e = mkloc(fn.decl["end"])
		if value == 0 then
			mark(buf, ns, s[1], s[2], {
				end_line = e[1],
				end_col = e[2],
				sign_text = " ",
				sign_hl_group = "UserCoverageMiss",
				hl_group = "UserCoverageMiss",
			})
		else
			mark(buf, ns, s[1], s[2], {
				end_line = e[1],
				end_col = e[2],
				sign_text = to_sign_text(value),
				sign_hl_group = "UserCoverageHit",
				hl_group = "UserCoverageHit",
			})
		end
	end

	for key, value in pairs(file_cov.s) do
		local statement = statement_map[key]
		local s = mkloc(statement.start)
		local e = mkloc(statement["end"])
		if value == 0 then
			mark(buf, ns, s[1], s[2], {
				end_line = e[1],
				end_col = e[2],
				virt_text_pos = "right_align",
				sign_text = " ",
				sign_hl_group = "UserCoverageMiss",
			})
		else
			mark(buf, ns, statement.start.line - 1, 0, {
				sign_text = to_sign_text(value),
				sign_hl_group = "UserCoverageHit",
			})
		end
	end

	for key, values in pairs(file_cov.b) do
		local item = branch_map[key]
		local locations = item.locations

		for idx, loc in ipairs(locations) do
			if values[idx] == 0 then
				local s = mkloc(loc.start)
				local e = mkloc(loc["end"])
				if item.type == "binary-expr" then
					mark(buf, ns, s[1], s[2], {
						end_line = e[1],
						end_col = e[2],
						hl_group = "UserCoveragerBranchNotTaken",
					})
				elseif item.type == "if" then
					mark(buf, ns, s[1], s[2], {
						end_line = e[1],
						end_col = e[2],
						hl_group = "UserCoverageMiss",
					})

					mark(buf, ns, s[1], math.max(0, s[2] - 1), {
						virt_text_pos = "overlay",
						virt_text = { { "I", "UserCoverageIfPathNotTaken" } },
					})
				end
			end
		end
	end
end

local function init()
	vim.cmd([[hi! link UserCoverageMiss DiffDelete]])
	vim.cmd([[hi! link UserCoverageHit DiffAdd]])
	vim.cmd([[hi! UserCoveragerBranchNotTaken guibg=yellow]])
	vim.cmd([[hi! UserCoverageIfPathNotTaken guibg=black guifg=yellow]])

	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		group = group,
		pattern = "*.ts,*.tsx,*.js,*.jsx",
		callback = apply_coverage,
	})
end

init()

return M
