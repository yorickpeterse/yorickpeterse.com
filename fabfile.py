import os
from fabric.api import *

env.hosts         = ['yorickpeterse@yorickpeterse.com:22960']
env.runit_service = '/home/yorickpeterse/service/yorickpeterse.com'
env.runit_deps    = ['memcached', 'mysql']
env.code_dir      = '/home/yorickpeterse/domains/yorickpeterse.com'
env.git_url       = 'git://github.com/YorickPeterse/yorickpeterse.com.git'

# Various commands to execute using a single SSH connection.
env.ssh_commands = {
    'update': 'sv d %s && git pull origin master && git reset --hard ' \
        '&& sv start %s'.format(env.runit_service, env.runit_service),
    'create': 'git init && git remote add origin %s && git pull origin master' \
        % env.git_url
}

def status():
    """Displays the status of the application."""

    run('sv status %s %s' % (' '.join(env.runit_deps), env.runit_service))

def deploy():
    """Updates the Git repository and deploys the website."""

    local('git checkout master')
    local('git push origin master')

    # Move into the project directory and update it.
    with cd(env.code_dir):
        run(env.ssh_commands['update'])

def setup_remote():
    """Sets up the required files and folders on remote servers."""

    run('mkdir %s' % env.code_dir)

    # Set up the Git repo.
    with cd(env.code_dir):
        run(env.ssh_commands['create'])

    # Add the Runit service
    setup_runit()

def setup_runit():
    """Sets up the Runit configuration file on remote servers."""

    # Create the Runit config for the server.
    local('cp config/runit tmp/runit')

    service_file = os.path.join(env.runit_service, 'run')
    content      = open('tmp/runit', 'r').read().format(code_dir = env.code_dir)
    handle       = open('tmp/runit', 'w')

    handle.write(content)
    handle.close()

    # Config file is in place. Create the service directory and upload the file.
    run('mkdir -p %s' % env.runit_service)
    put('tmp/runit', service_file)
    run('chmod +x %s' % service_file)

    local('rm tmp/runit')
