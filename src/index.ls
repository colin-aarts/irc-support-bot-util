
#	irc-support-js-util
#	-------------------
#	Utility commands plug-in for irc-support-bot
#	This is an official plug-in
#
#	Provides five commands: 'admins', 'search', 'info', 'topic' and 'commands'

'use strict'


util    = require 'util'
js      = require 'js-extensions'


module.exports = ->

	#
	#	Command: admins
	#

	this.register_special_command do
		name: 'admins'
		description: 'Display a list of my administrators'
		admin_only: false
		fn: (event, input_data, output_data) ~>

			if '?' in input_data.flags
				message = 'Display a list of my administrators'
			else
				message = []
				for admin in @bot-options.admins
					nick = admin.nick or '(null)'
					host = admin.host or '(null)'
					message.push "nick: #{nick} • host: #{host}"

			this.send 'notice', event.person.nick, message



	#
	#	Command: commands
	#

	this.register_special_command do
		name: 'commands'
		description: 'Display a list of special commands I support'
		admin_only: false
		fn: (event, input_data, output_data) ~>

			if '?' in input_data.flags
				message = [
					'''Syntax: commands[/v] • Display a list of special commands I support'''
					'''--- This command supports the following flags ---'''
					'''v • verbose: also lists the description and permission level for each command'''
				]
			else if 'v' in input_data.flags # Verbose mode
				message = []
				for own name, command of @special_commands
					permission = if command.admin_only then ' • admin only' else ''
					message.push "#{command.name} • #{command.description}#{permission}"
			else
				message = Object.keys @special_commands
				message = message.join ' • '

			this.send 'notice', event.person.nick, message



	#
	#	Command: topic
	#

	this.register_special_command do
		name: 'topic'
		description: 'Display the topic for the current channel; only works in channels'
		admin_only: false
		fn: (event, input_data, output_data) ~>

			if '?' in input_data.flags
				message = 'Display the channel topic for the current channel; only works in channels'
				this.send 'notice', event.person.nick, message
				return
			else
				return if event.recipient[0] isnt '#'
				channel, message <~ @irc.topic event.recipient
				this.send output_data.method, output_data.recipient, """Topic for #channel is « #message »"""



	#
	#	Command: info
	#

	this.register_special_command do
		name: 'info'
		description: 'Display information about a factoid'
		admin_only: false
		fn: (event, input_data, output_data) ~>

			if '?' in input_data.flags
				message = "info <factoid-name> • Display information about a factoid"
			else if not input_data.args.trim()
				message = "Sorry, I didn't see a factoid name there!"
			else if not input_data.args.trim() of @factoids
				message = "Sorry, I couldn't find a factoid with the name « #{input_data.args} »"
			else
				message = []
				factoid_name = input_data.args.trim()
				factoid_content = @factoids[factoid_name]
				is_alias = /^alias:/.test factoid_content
				factoid_original_name = if is_alias then (factoid_content.match /^alias:(.*)/)[1] else factoid_name
				factoid_original_content = @factoids[factoid_original_name]
				aliases = @factoid_get_aliases factoid_original_name

				# Alias details
				if is_alias
					message.push "« #{factoid_name} » is an alias for « #{factoid_original_name} »"
				else
					message.push "« #{factoid_name} » is not an alias"

				if aliases
					message.push "The following names are aliases for « #{factoid_original_name} »: #{aliases.join ' • '}"
				else
					message.push "There are no aliases for « #{factoid_original_name} »"

				# Factoid content
				message.push "« #{factoid_original_name} » is « #{factoid_original_content} »"

			this.send 'notice', event.person.nick, message



	#
	#	Command: search
	#

	this.register_special_command do
		name: 'search'
		description: 'Search the factoids store'
		admin_only: false
		fn: (event, input_data, output_data) ~>

			if '?' in input_data.flags
				message = [
					'''Syntax: search[/oanc] • Search the factoids store'''
					'''--- This command supports the following flags ---'''
					'''o • original: only search 'original' factoids; that is, factoids that are not aliases'''
					'''a • aliases: only search aliases'''
					'''n • names: only search factoid names'''
					'''c • content: only search factoid content'''
					'''Note: flags 'o' and 'a' are mutually exclusive'''
					'''Note: flags 'n' and 'c' are mutually exclusive'''
				]
			else if not input_data.args
				message = '''Sorry, I didn't see a search term there!'''
			else
				query = new RegExp (js.re_escape input_data.args), 'i'
				results = []
				max_results = 20
				flag_n = 'n' in input_data.flags
				flag_c = 'c' in input_data.flags
				flag_o = 'o' in input_data.flags
				flag_a = 'a' in input_data.flags

				for own factoid_name, factoid_content of @factoids
					is_alias = /^alias:/.test factoid_content

					# Names only
					if flag_n and not flag_c
						if query.test factoid_name
							if  (flag_a and not flag_o and is_alias)     or	# Aliases only
								(flag_o and not flag_a and not is_alias) or	# Originals only
								(not flag_a and not flag_o)					# All
									results.push factoid_name

					# Content only
					else if flag_c and not flag_n
						if query.test factoid_content
							if  (flag_a and not flag_o and is_alias)     or	# Aliases only
								(flag_o and not flag_a and not is_alias) or	# Originals only
								(not flag_a and not flag_o)					# All
									results.push factoid_name

					# Both names & content
					else
						if (query.test factoid_name) or (query.test factoid_content)
							if  (flag_a and not flag_o and is_alias)     or	# Aliases only
								(flag_o and not flag_a and not is_alias) or	# Originals only
								(not flag_a and not flag_o)					# All
									results.push factoid_name

				if results.length
					num_results = results.length
					showing = if num_results > max_results then " (showing #{max_results})" else ''
					results = results.slice 0, max_results
					message = "Found #{num_results} results for query « #{input_data.args} »#{showing}: #{results.join ' • '}"
				else
					message = "Sorry, I couldn't find any results for query « #{input_data.args} »"

			this.send 'notice', event.person.nick, message
