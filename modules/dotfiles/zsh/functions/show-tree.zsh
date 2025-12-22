
# functions/show-tree.zsh
function show_tree() {
    ll
}

# On attache la fonction au hook Zsh
chpwd_functions+=(show_tree)
