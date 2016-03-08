define ->

	# [fullLine, lineNumber, messageType, message]
	LINE_SPLITTER_REGEX = /^\[(\d+)].*>\s(INFO|WARN|ERROR)\s-\s(.*)$/

	MESSAGE_LEVELS = {
		"INFO": "info"
		"WARN": "warning"
		"ERROR": "error"
	}

	BiberLogParser = (text, options) ->
		if typeof text != 'string'
			throw new Error("BiberLogParser Error: text parameter must be a string")
		@text = text.replace(/(\r\n)|\r/g, '\n')
		@options = options || {}
		@lines = text.split('\n')
		return

	(->
		@parse = () ->
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
	).call(BiberLogParser.prototype)

	BiberLogParser.parse = (text, options) ->
		new BiberLogParser(text, options).parse()

	return BiberLogParser
