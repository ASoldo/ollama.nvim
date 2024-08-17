local M = {}
local selected_model = nil

-- Function to create the input window
local function create_input_window()
	if not selected_model then
		vim.notify("Please select a model first.", vim.log.levels.WARN)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true) -- create a new empty buffer
	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")
	local win_height = 1
	local win_width = math.floor(width * 0.8)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		col = math.floor((width - win_width) / 2),
		row = math.floor(height / 2),
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

-- Function to display the output window with Markdown syntax highlighting
local function display_output(result)
	-- Close only if there are more than one windows open
	if #vim.api.nvim_tabpage_list_wins(0) > 1 then
		vim.cmd("close")
	end

	local output_buf = vim.api.nvim_create_buf(false, true)
	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")
	local win_height = math.floor(height * 0.3)
	local win_width = math.floor(width * 0.8)

	local output_win = vim.api.nvim_open_win(output_buf, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		col = math.floor((width - win_width) / 2),
		row = math.floor((height - win_height) / 2),
		anchor = "NW",
		style = "minimal",
		border = "rounded",
	})

	-- Set the buffer to use Markdown syntax highlighting
	vim.api.nvim_buf_set_option(output_buf, "filetype", "markdown")

	vim.api.nvim_buf_set_option(output_buf, "rnu", true)
	vim.api.nvim_buf_set_option(output_buf, "nu", true)

	-- Insert the result after setting the filetype to ensure correct syntax highlighting
	vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, vim.split(result, "\n"))

	-- Mark the buffer as unlisted and non-modifiable
	vim.api.nvim_buf_set_option(output_buf, "buflisted", false)
	vim.api.nvim_buf_set_option(output_buf, "modifiable", false)
	-- Ensure the buffer is wiped when hidden
	vim.api.nvim_buf_set_option(output_buf, "bufhidden", "wipe")
end

-- Function to send the query to the ollama model
function M.send_query()
	if not selected_model then
		vim.notify("No model selected.", vim.log.levels.WARN)
		return
	end

	local query = vim.fn.getline("."):sub(8) -- get the query text, removing the "Query: " prompt

	-- Close the input window before doing anything else
	vim.api.nvim_win_close(M.input_win, true)

	-- Run the ollama command and capture the output
	local handle = io.popen("ollama run " .. selected_model .. ' <<< "' .. query .. '"')
	local result = handle:read("*a")
	handle:close()

	-- Display the output in a new floating window with Markdown syntax highlighting
	display_output(result)
end

-- Function to select a model using telescope.nvim
function M.select_model()
	local handle = io.popen("ollama ps")
	local result = handle:read("*a")
	handle:close()

	-- Parse the result to get the model names
	local models = {}
	for line in result:gmatch("[^\r\n]+") do
		if line:match("^%S") then
			local model_name = line:match("^(%S+)")
			if model_name ~= "NAME" then
				table.insert(models, model_name)
			end
		end
	end

	if #models == 0 then
		vim.notify("No models available.", vim.log.levels.ERROR)
		return
	end

	-- Use telescope to select the model
	require("telescope.pickers")
		.new({}, {
			prompt_title = "Select Ollama Model",
			finder = require("telescope.finders").new_table({
				results = models,
			}),
			sorter = require("telescope.config").values.generic_sorter({}),
			attach_mappings = function(_, map)
				map("i", "<CR>", function(prompt_bufnr)
					local selection = require("telescope.actions.state").get_selected_entry(prompt_bufnr)
					if selection then
						selected_model = selection[1]
						vim.notify("Selected model: " .. selected_model, vim.log.levels.INFO)
						require("telescope.actions").close(prompt_bufnr)
						create_input_window()
					else
						vim.notify("No model selected. Please select a model to proceed.", vim.log.levels.WARN)
					end
				end)
				return true
			end,
		})
		:find()
end

-- Command to start the interaction
function M.start()
	M.select_model()
end

return M
