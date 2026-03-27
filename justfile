alias p := push
alias pub := publish
alias c := clean

readme:
    bash readme.sh > readme.md

update-vcs-packages:
    bash update-vcs.sh

push FLAGS="-u" BRANSH="aurora":
    git push {{FLAGS}} github {{BRANSH}}
    git push {{FLAGS}} gitlab {{BRANSH}}
    git push {{FLAGS}} codeberg {{BRANSH}}
    git push {{FLAGS}} disroot {{BRANSH}}
    git push {{FLAGS}} tangled {{BRANSH}}
    git push {{FLAGS}} codefloe {{BRANSH}}

publish PKG:
    aurpublish {{PKG}}

clean:
    git clean -ffdx
