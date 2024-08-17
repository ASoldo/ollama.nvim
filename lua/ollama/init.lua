local M = {}

-- Function to create the input window
local function create_input_window()
	local buf = vim.api.nvim_create_buf(false, true) -- create a new empty buffer
	local width = vim.api.nvim_get_option("columns")
	local win_height = 3
	local win_width = math.floor(width)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		col = 0,
		row = 0,
		anchor = "NW",
		style = "minimal",
		border = "rounded",
	})

	vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
	vim.fn.prompt_setprompt(buf, "Query: ")

	-- Mark the buffer as unlisted, so it's not part of the buffer list
	vim.api.nvim_buf_set_option(buf, "buflisted", false)
	-- Ensure the buffer is wiped when hidden
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

	vim.cmd("startinsert") -- start in insert mode

	-- Capture the input when Enter is pressed
	vim.api.nvim_buf_set_keymap(
		buf,
		"i",
		"<CR>",
		"<cmd>lua require('ollama').send_query()<CR>",
		{ noremap = true, silent = true }
	)

	M.input_win = win
	M.input_buf = buf
end

-- Function to create the output window
local function create_output_window()
	local buf = vim.api.nvim_create_buf(false, true) -- create a new empty buffer
	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")
	local win_height = math.floor(height * 0.8)
	local win_width = math.floor(width)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		col = 0,
		row = 3, -- Below the input window
		anchor = "NW",
		style = "minimal",
		border = "rounded",
	})

	-- Mark the buffer as unlisted and non-modifiable
	vim.api.nvim_buf_set_option(buf, "buflisted", false)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	-- Ensure the buffer is wiped when hidden
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

	M.output_win = win
	M.output_buf = buf
end

-- Function to display the output in the output window
local function display_output(result)
	vim.api.nvim_buf_set_option(M.output_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(M.output_buf, -1, -1, false, vim.split(result, "\n"))
	vim.api.nvim_buf_set_option(M.output_buf, "modifiable", false)
	vim.api.nvim_set_current_win(M.output_win) -- Move cursor to the output window
end

-- Function to send the query to the ollama model
function M.send_query()
	local query = vim.fn.getline("."):sub(8) -- get the query text, removing the "Query: " prompt

	-- Clear the input field
	vim.api.nvim_buf_set_lines(M.input_buf, 0, -1, false, { "Query: " })
	vim.cmd("startinsert")

	-- Run the ollama command and capture the output
	local handle = io.popen('ollama run jarvis <<< "' .. query .. '"')
	local result = handle:read("*a")
	handle:close()

	-- Display the output in the output window
	display_output(result)
end

-- Function to start the interaction by creating both windows
function M.start()
	create_input_window()
	create_output_window()
end

return M
