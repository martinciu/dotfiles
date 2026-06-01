# md through the pager (glow -p → $PAGER). Inherits md's terminal-width wrap.
function mdp --description 'md through the pager (glow -p)' --wraps md
    md -p $argv
end
