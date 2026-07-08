#!/usr/bin/env -S just --justfile
# SPDX-FileCopyrightText: Arch Linux contributors
# SPDX-License-Identifier: 0BSD

set lazy

packager := `sh -c 'source /usr/share/makepkg/util/config.sh && source_makepkg_config && echo $PACKAGER'`

packages_list := `git submodule foreach -q "echo \"'\$name'\"" | xargs -d '\n'`
packages_updatable := `git submodule foreach -q "if [[ -f .nvchecker.toml ]]; then echo \"'\$name'\"; fi" | xargs -d'\n'`

[doc("Initialises a package")]
init package:
	[[ ! -e {{package}} ]]
	mkdir -p {{package}}/LICENSES
	git -C {{package}} init -b master
	cp _template/gitignore.template {{package}}/.gitignore
	cp .gitattributes {{package}}/.gitattributes
	cp LICENSE {{package}}/LICENSE
	ln -s ../LICENSE {{package}}/LICENSES/0BSD.txt
	sed _template/PKGBUILD.template \
		-e 's/##PACKAGER##/{{packager}}' \
		-e 's/##PKGNAME##/{{package}}' \
		-e {{ if package =~ '\-git$' { 's/##GITPKGVER##//' } else { '/##GITPKGVER##/,+4d' } }}

[doc("Clones an AUR package")]
clone package:
	git submodule add ssh://aur@aur.archlinux.org/{{package}}

[doc("Updates all submodules to latest")]
sync:
	git submodule update --recursive --remote

[doc("Commits changes in a package (and in the workspace)")]
commit package *message:
	git -C {{package}} commit -am "{{message}}"
	git commit -am "{{package}}: {{message}}"

[doc("Push all local changes to the AUR")]
push:
	git submodule foreach "git push"
	git push

[doc("Cleans the workspace")]
[confirm("This will delete all ignored and untracked files, and reset all uncommitted changes across all packages. Continue? [y/N]")]
clean:
	git submodule foreach "git clean -xdff"
	git clean -xdff

[doc("Checks the licensing information across all packages")]
licenses:
	pkgctl license check {{packages_list}}
	reuse lint -q

[doc("Checks for updates using nvchecker")]
updates:
	pkgctl version check {{packages_updatable}}

alias c := commit
alias s := sync
alias p := push
alias upd := updates
alias lic := licenses
