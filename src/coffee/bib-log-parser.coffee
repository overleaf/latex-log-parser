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


	MULTILINE_WARNING_REGEX = /^Warning--(.+)\n--line (\d+) of file (.+)$/m
	SINGLELINE_WARNING_REGEX = /^Warning--(.+)$/m

	consume = (logText, regex) ->
		result = []
		re = regex
		while match = re.exec(logText)
			[fullMatch, message, lineNumber, fileName] = match
			index = match.index
			newEntry = {
				file: fileName,
				level: "warning",
				message: message,
				line: lineNumber,
				raw: fullMatch
			}
			result.push newEntry
			logText = (
				(match.input.slice(0, index)) +
				(match.input.slice(index+fullMatch.length+1, match.input.length))
			)
		return result

	consumeMultilineWarnings = (logText) ->
		consume(logText, MULTILINE_WARNING_REGEX)

	(->
		@parseBibtex = () ->
			result = {
				all: [],
				errors: [],
				warnings: [],
				files: [],       # not used
				typesetting: []  # not used
			}
			multilineWarnings = consumeMultilineWarnings(@text)
			result.all = multilineWarnings
			result.warnings = multilineWarnings
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
