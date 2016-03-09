define ->

	# [fullLine, lineNumber, messageType, message]
	LINE_SPLITTER_REGEX = /^\[(\d+)].*>\s(INFO|WARN|ERROR)\s-\s(.*)$/

	MESSAGE_LEVELS = {
		"INFO": "info"
		"WARN": "warning"
		"ERROR": "error"
	}

	BibLogParser = (text, options) ->
		if typeof text != 'string'
			throw new Error("BibLogParser Error: text parameter must be a string")
		@text = text.replace(/(\r\n)|\r/g, '\n')
		@options = options || {}
		@lines = text.split('\n')
		return

	consume = (logText, regex, process) ->
		text = logText
		result = []
		re = regex
		iterationCount = 0
		while match = re.exec(text)
			iterationCount += 1
			if iterationCount >= 10000
				return result
			newEntry = process(match)
			result.push newEntry
			text = (
				(match.input.slice(0, match.index)) +
				(match.input.slice(match.index+match[0].length+1, match.input.length))
			)
		return [result, text]

	MULTILINE_WARNING_REGEX = /^Warning--(.+)\n--line (\d+) of file (.+)$/m
	SINGLELINE_WARNING_REGEX = /^Warning--(.+)$/m
	MULTILINE_ERROR_REGEX = /^(.*)---line (\d+) of file (.*)\n([^]+?)\nI'm skipping whatever remains of this entry$/m

	(->
		@parseBibtex = () ->
			result = {
				all: [],
				errors: [],
				warnings: [],
				files: [],       # not used
				typesetting: []  # not used
			}
			[multiLineWarnings, remainingText] = consume @text, MULTILINE_WARNING_REGEX, (match) ->
				[fullMatch, message, lineNumber, fileName] = match
				{
					file: fileName,
					level: "warning",
					message: message,
					line: lineNumber,
					raw: fullMatch
				}
			result.all = multiLineWarnings
			result.warnings = multiLineWarnings
			[singleLineWarnings, remainingText] = consume remainingText, SINGLELINE_WARNING_REGEX, (match) ->
				[fullMatch, message] = match
				{
					file: null,
					level: "warning",
					message: message,
					line: null,
					raw: fullMatch
				}
			result.all = result.all.concat(singleLineWarnings)
			result.warnings = result.warnings.concat(singleLineWarnings)
			[multiLineErrors, remainingText] = consume remainingText, MULTILINE_ERROR_REGEX, (match) ->
				[fullMatch, firstMessage, lineNumber, fileName, secondMessage] = match
				{
					file: fileName,
					level: "error",
					message: firstMessage + '\n' + secondMessage,
					line: lineNumber,
					raw: fullMatch
				}
			result.all = result.all.concat(multiLineErrors)
			result.errors = multiLineErrors
			return result

		@parseBiber = () ->
			result = {
				all: [],
				errors: [],
				warnings: [],
				files: [],       # not used
				typesetting: []  # not used
			}
			@lines.forEach (line) ->
				match = line.match(LINE_SPLITTER_REGEX)
				if match
					[fullLine, lineNumber, messageType, message] = match
					newEntry = {
						file: null,
						level: MESSAGE_LEVELS[messageType] || "INFO",
						message: message,
						line: null,
						raw: fullLine
					}
					# try extract file, line-number and the 'real' message from lines like:
					#   BibTeX subsystem: /.../original.bib_123.utf8, line 8, syntax error: it's bad
					lineMatch = newEntry.message.match(/^BibTeX subsystem: \/.+\/(\w+\.\w+)_.+, line (\d+), (.+)$/)
					if lineMatch && lineMatch.length == 4
						[_, fileName, lineNumber, realMessage] = lineMatch
						newEntry.file = fileName
						newEntry.line = lineNumber
						newEntry.message = realMessage
					result.all.push newEntry
					switch newEntry.level
						when 'error' then result.errors.push newEntry
						when 'warning'  then result.warnings.push newEntry
			return result

		@parse = () ->
			firstLine = @lines[0]
			if firstLine.match(/^.*INFO - This is Biber.*$/)
				@parseBiber()
			else if firstLine.match(/^This is BibTeX, Version.+$/)
				@parseBibtex()
			else
				throw new Error("BibLogParser Error: cannot determine whether text is biber or bibtex output")

	).call(BibLogParser.prototype)

	BibLogParser.parse = (text, options) ->
		new BibLogParser(text, options).parse()

	return BibLogParser
