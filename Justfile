#!/usr/bin/env -S just --justfile
# SPDX-FileCopyrightText: Arch Linux contributors
# SPDX-License-Identifier: 0BSD

set lazy

packager := `sh -c 'source /usr/share/makepkg/util/config.sh && source_makepkg_config && echo $PACKAGER'`

packages_list := `git submodule foreach -q "echo \"'\$name'\"" | xargs -d '\n'`
packages_updatable := `git submodule foreach -q "if [[ -f .nvchecker.toml ]]; then echo \"'\$name'\"; fi" | xargs -d'\n'`

[doc("Initialises a package")]
init package:
	@[[ ! -e {{package}} ]]
	mkdir -p {{package}}
	git -C {{package}} init -b master
	git -C {{package}} remote add origin ssh://aur@aur.archlinux.org/{{package}}
	git -C {{package}} fetch
	@just gitfiles {{package}}
	@just license {{package}}
	cp _template/REUSE.toml.template {{package}}/REUSE.toml
	sed _template/PKGBUILD.template \
		-e 's/##PACKAGER##/{{packager}}/' \
		-e 's/##PKGNAME##/{{package}}/' \
		-e {{ if package =~ '\-git$' { 's/##GITPKGVER##//' } else { '/##GITPKGVER##/,+4d' } }} \
		> {{package}}/PKGBUILD

[doc("Clones an AUR package")]
clone package:
	git submodule add ssh://aur@aur.archlinux.org/{{package}}

[doc("Adopts an orphaned AUR package")]
adopt package:
	{{ error("adoption requires filing a request, cannot set required comment via ssh") }}
	ssh aur@aur.archlinux.org adopt {{package}}
	git submodule add ssh://aur@aur.archlinux.org/{{package}}
	git commit -auall -m "adopt {{package}}"

[doc("Updates all submodules to latest")]
sync:
	git submodule update --recursive --remote

[doc("Creates the initial commit of a package and sets up the submodule in the workspace")]
init-commit package:
	git -C {{package}} add .
	git -C {{package}} commit -m "initial commit"
	git submodule add ./upm upm
	git submodule absorbgitdirs
	git add .
	git commit -m "{{package}}: initial commit"

[doc("Commits changes in a package (and in the workspace)")]
commit package *message:
	git -C {{package}} add .
	git -C {{package}} commit -m "{{message}}"
	git add .
	git commit -m "{{package}}: {{message}}"

[doc("Amends changes in a package (and in the workspace)")]
amend package:
	git -C {{package}} add .
	git -C {{package}} commit --amend --no-edit
	git add .
	git commit --amend --no-edit

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

[doc("Adds LICENSE files to the package")]
license package:
	mkdir -p {{package}}/LICENSES
	cp LICENSE {{package}}/LICENSE
	ln -s ../LICENSE {{package}}/LICENSES/0BSD.txt

[doc("Adds .git* files to the package")]
gitfiles package:
	cp _template/gitignore.template {{package}}/.gitignore

[doc("Checks for updates using nvchecker")]
updates:
	pkgctl version check {{packages_updatable}}

alias c := commit
alias s := sync
alias p := push
alias upd := updates
alias lic := licenses
