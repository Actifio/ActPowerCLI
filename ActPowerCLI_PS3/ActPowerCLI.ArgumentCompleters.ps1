# udsinfo tab completer
function udsinfoSubCommandCompletion {

	param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

	# if no string is given, it will start from the top of the list.
	# if a string is given, ex: lsh, it will narrow down the list to just lshost and complete that
	if ( $wordToComplete -eq "" ) 
	{
		$ENV:UDSINFOCMDS -split " " | ForEach-Object { New-CompletionResult -CompletionText $_ }
	} else
	{
		$ENV:UDSINFOCMDS -split " " -match "^$wordToComplete" | ForEach-Object { New-CompletionResult -CompletionText $_ }
	}

}

function udstaskSubCommandCompletion {

	param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

	# if no string is given, it will start from the top of the list.
	# if a string is given, ex: lsh, it will narrow down the list to just lshost and complete that
	if ( $wordToComplete -eq "" ) 
	{
		$ENV:UDSTASKCMDS -split " " | ForEach-Object { New-CompletionResult -CompletionText $_ }
	} else
	{
		$ENV:UDSTASKCMDS -split " " -match "^$wordToComplete" | ForEach-Object { New-CompletionResult -CompletionText $_ }
	}

}

function usvcinfoSubCommandCompletion {
	param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

	# if no string is given, it will start from the top of the list.
	# if a string is given, ex: lsh, it will narrow down the list to just lshost and complete that
	if ( $wordToComplete -eq "" ) 
	{
		$ENV:USVCINFOCMDS -split " " | ForEach-Object { New-CompletionResult -CompletionText $_ }
	} else
	{
		$ENV:USVCINFOCMDS -split " " -match "^$wordToComplete" | ForEach-Object { New-CompletionResult -CompletionText $_ }
	}


}

function usvctaskSubCommandCompletion {

	param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

	# if no string is given, it will start from the top of the list.
	# if a string is given, ex: lsh, it will narrow down the list to just lshost and complete that
	if ( $wordToComplete -eq "" ) 
	{
		$ENV:USVCTASKCMDS -split " " | ForEach-Object { New-CompletionResult -CompletionText $_ }
	} else
	{
		$ENV:USVCTASKCMDS -split " " -match "^$wordToComplete" | ForEach-Object { New-CompletionResult -CompletionText $_ }
	}
}

