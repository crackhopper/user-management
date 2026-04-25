# lib/install_steps/scripts_dir.sh — 部署 ~/scripts (templates/)
# 依赖：SCRIPTS_SRC、UM_DEPLOY_SCRIPTS_DEFAULT
# -----------------------------------------------------------------------------

UM_STEPS+=(scripts_dir)

um_step_scripts_dir_label()   { echo "部署 ~/scripts（复制 templates/）"; }
um_step_scripts_dir_default() { echo "${UM_DEPLOY_SCRIPTS_DEFAULT:-false}"; }

um_step_scripts_dir_status() {
    local home="$2"
    sudo test -d "$home/scripts" && echo true || echo false
}

um_step_scripts_dir_apply() {
    local user="$1" home="$2"
    sudo cp -r "$SCRIPTS_SRC" "$home/scripts"
    sudo chown -R "$user:$user" "$home/scripts"
}

um_step_scripts_dir_remove() {
    local home="$2"
    sudo rm -rf "$home/scripts"
}
