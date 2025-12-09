alias p := push
alias pub := publish
alias c := clean

push FLAGS="-u" BRANSH="aurora":
    git push {{FLAGS}} github {{BRANSH}}
    git push {{FLAGS}} gitlab {{BRANSH}}
    git push {{FLAGS}} codeberg {{BRANSH}}
    git push {{FLAGS}} disroot {{BRANSH}}

publish PKG:
    aurpublish {{PKG}}

clean:
    git clean -fdx
