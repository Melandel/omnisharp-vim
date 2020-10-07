function! Melandel#GetCsprojsFromSlnFile(sln_or_dir)
	if isdirectory(a:sln_or_dir)
		return [a:sln_or_dir]
	endif

	let sln_folder = fnamemodify(a:sln_or_dir, ':h')
	let lineList = readfile(a:sln_or_dir)
	let csprojLines = filter(lineList, { _,x -> stridx(x, '.csproj') >= 0})
	let csprojFolders = map(csprojLines, {_,x -> fnamemodify(sln_folder . '\' . matchlist(x, '\v"((\a|\.|\:|\\|\/|\d|_|-)*\.csproj)"')[1], ':p:h')})
	return reverse(sort(reverse(csprojFolders)))
endfunction

function! Melandel#BuildCsprojsToSlnDictionary(sln_or_dir)
	if !exists('g:csprojs2sln')
		let g:csprojs2sln = {}
	endif

	let file_ext = fnamemodify(a:sln_or_dir, ':e')
	if file_ext ==? 'sln'
		let g:csprojs2sln[a:sln_or_dir] = a:sln_or_dir

		for csproj_dir in Melandel#GetCsprojsFromSlnFile(a:sln_or_dir)
			let g:csprojs2sln[csproj_dir] = a:sln_or_dir
		endfor
	endif

	return g:csprojs2sln
endfunction

function! Melandel#GetCsprojsToSlnDictionary()
	return get(g:, 'csprojs2sln', {})
endfunction

function! Melandel#Autocomplete()
	if Melandel#IsFollowedByAnOpeningParenthesis()
		call Melandel#AdaptSnippetToAlreadyWrittenArguments([trigger, snippet])
	else
		if !has_key(s:generated_snippets, trigger)
				call UltiSnips#AddSnippetWithPriority(trigger, snippet, trigger, 'iw', 'cs', 1)
				let s:generated_snippets[trigger] = snippet
		endif
		call UltiSnips#CursorMoved()
		call UltiSnips#ExpandSnippetOrJump()
	endif
endfunction

function! Melandel#IsFollowedByAnOpeningParenthesis()
	return strcharpart(getline('.')[col('.')-1:], 0, 1) == '('
endfunction

function! Melandel#ParseArgumentsAndAdaptSnippet(trigger, snippet, generated_snippets, response) abort
	let punctuationCharacters = filter(a:response.Body.Spans, { _,x -> x.Type == 14 })
	let number_of_opening_parens_met = 1
	let argumentList = {'start': {'lnum':0, 'col':0}, 'end': {'lnum':0, 'col':0}, 'separators': []}
	let number_of_opening_parens_met = 0
	for punct in punctuationCharacters
		let char = strcharpart(getbufline(bufnr('%'), punct.StartLine)[0],punct.StartColumn-1,1)
		echomsg char punct
			if char == '('
					let number_of_opening_parens_met += 1
					if number_of_opening_parens_met == 1
							let argumentList.start = {'lnum': punct.StartLine, 'col': punct.StartColumn-1}
					endif
			elseif char == ')'
					let number_of_opening_parens_met -= 1
					if number_of_opening_parens_met == 0
							let argumentList.end = {'lnum': punct.StartLine, 'col': punct.StartColumn-1}
							break
					endif
			elseif char == ',' && number_of_opening_parens_met == 1
					call add(argumentList.separators, {'lnum': punct.StartLine, 'col': punct.StartColumn-1})
			endif
	endfor
	let args_as_string = Melandel#GetBufSubstring(bufnr('%'), argumentList.start.lnum, argumentList.start.col, argumentList.end.lnum, argumentList.end.col)
	let args_as_list = Melandel#GetArgumentList(argumentList)
	echomsg 'argumentList' argumentList
	echomsg 'args_as_string' args_as_string
	let trigger = Melandel#AdaptSnippetTrigger(a:trigger, args_as_string)
	let snippet = Melandel#AdaptSnippetBody(a:snippet, args_as_list)
	echomsg 'trigger' trigger
	echomsg 'snippet' snippet
	if argumentList.start.lnum == argumentList.end.lnum
		call setpos('.', [bufnr('%'), argumentList.end.lnum, argumentList.end.col+2, 0])
	else
		exec 'normal!' (argumentList.end.lnum-argumentList.start.lnum).'J'
		normal! $
	endif
	if !has_key(a:generated_snippets, trigger)
		call UltiSnips#AddSnippetWithPriority(trigger, snippet, trigger, 'iw', 'cs', 1)
		let a:generated_snippets[trigger] = snippet
	endif
	call UltiSnips#CursorMoved()
	call UltiSnips#ExpandSnippetOrJump()
endfunction

function! Melandel#GetBufSubstring(bufnr, startline, startcol, endline, endcol)
	let lines = getbufline(a:bufnr, a:startline, a:endline)
	echomsg 'lines' lines
	if a:startline == a:endline
	echomsg 'lines2' strcharpart(lines[0], a:startcol, a:endcol-a:startcol+1)
		return strcharpart(lines[0], a:startcol, a:endcol-a:startcol+1)
	else
		let lines[0] = strcharpart(lines[0], a:startcol)
		let lines[-1] = strcharpart(lines[-1], 0, a:endcol)
	echomsg 'lines3' join(lines, '\r')
		return join(lines, '\r')
	endif
endfunction

function! Melandel#GetArgumentList(argumentList)
	if len(a:argumentList.separators) == 0
		return [Melandel#GetBufSubstring(bufnr('%'), a:argumentList.start.lnum, a:argumentList.start.col+1, a:argumentList.end.lnum, a:argumentList.end.col-1)]
	endif
	let list = []
	for i in range(len(a:argumentList.separators)+1)
		if i == 0
			call add(list, Melandel#GetBufSubstring(bufnr('%'), a:argumentList.start.lnum, a:argumentList.start.col+1,  a:argumentList.separators[i].lnum,  a:argumentList.separators[i].col-1))
		elseif i == len(a:argumentList.separators)
			call add(list, Melandel#GetBufSubstring(bufnr('%'), a:argumentList.separators[i-1].lnum,  a:argumentList.separators[i-1].col+1, a:argumentList.end.lnum, a:argumentList.end.col-1))
		else
			call add(list, Melandel#GetBufSubstring(bufnr('%'), a:argumentList.separators[i-1].lnum,  a:argumentList.separators[i-1].col+1, a:argumentList.separators[i].lnum, a:argumentList.separators[i].col-1))
		endif
	endfor
	return map(list, { _,x -> trim(x) })
endfunc

function! Melandel#AdaptSnippetTrigger(trigger, written_arguments)
	echomsg 'trigger' a:trigger
	echomsg 'written_arguments' a:written_arguments
	return a:trigger.a:written_arguments
endfunction

function! Melandel#AdaptSnippetBody(snippet, argument_list)
  let snippet = a:snippet
  let snippet_params = map(split(snippet[stridx(snippet, '('):stridx(snippet, ')')-1], ','), { _,x -> trim(x) })
  if len(snippet_params) >= len(a:argument_list)
    for i in range(min([len(snippet_params), len(a:argument_list)]))
      let placeholder_default_value_pos = stridx(snippet, '${'.(i+1))+ 4
      let placeholder_end_pos = stridx(snippet, '}', placeholder_default_value_pos)
      let snippet = snippet[:placeholder_default_value_pos-1].a:argument_list[i].snippet[placeholder_end_pos:]
    endfor
  else
			" add already written parameters to the end of the snippet, inside the
			" parens, as 'last arguments'
  endif
  return snippet
endfunction

