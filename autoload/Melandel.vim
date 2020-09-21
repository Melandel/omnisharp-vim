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
