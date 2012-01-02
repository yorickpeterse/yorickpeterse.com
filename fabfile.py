import os
from fabric.api import *

env.hosts         = ['yorickpeterse@stewie.yorickpeterse.com']
env.runit_service = '/home/yorickpeterse/service/yorickpeterse.com'
env.code_dir      = '/home/yorickpeterse/domains/yorickpeterse.com'
env.git_url       = 'git://github.com/YorickPeterse/yorickpeterse.com.git'
env.config_files  = ['config', 'database', 'unicorn']

# Various commands to execute using a single SSH connection.
env.ssh_commands = {
    'update': 'sv d %s && git pull origin master && git reset --hard ' \
        '&& rake db:migrate && sv start %s' \
        % (env.runit_service, env.runit_service),

    'create': 'git init && git remote add origin %s && ' \
        'git pull origin master' % env.git_url,

    'install_gems': '`cat .rvmrc` && rvm gemset import .gems'
}

def status():
    """Displays the status of the application."""

    run('sv status %s' % env.runit_service)

def deploy():
    """Updates the Git repository and deploys the website."""

    local('git checkout master')
    local('git push origin master')

    # Move into the project directory and update it.
    with cd(env.code_dir):
        run(env.ssh_commands['update'])
        run(env.ssh_commands['install_gems'])

def setup():
    """Sets up the required files and folders on remote servers."""

    run('mkdir -p %s' % env.code_dir)

    # Set up the Git repo.
    with cd(env.code_dir):
        run(env.ssh_commands['create'])
        run(env.ssh_commands['install_gems'])

    setup_config()
    setup_runit()

def setup_runit():
    """Sets up the Runit configuration file on remote servers."""

    # Create the Runit config for the server.
    local('cp config/runit/run tmp/run')
    local('cp config/runit/log_run tmp/log_run')

    run_file = os.path.join(env.runit_service, 'run')
    log_dir  = os.path.join(env.runit_service, 'log')
    log_file = os.path.join(log_dir, 'run')

    run_content = open('tmp/run', 'r').read().format(code_dir = env.code_dir)
    log_content = open('tmp/log_run', 'r').read().format(
        service_dir = env.runit_service
    )

    open('tmp/run', 'w').write(run_content)
    open('tmp/log_run', 'w').write(log_content)

    # Config file is in place. Create the service directory and upload the file.
    run('mkdir -p %s' % log_dir)

    put('tmp/run', run_file)
    put('tmp/log_run', log_file)

    run('chmod +x %s && chmod +x %s' % (run_file, log_file))

    local('rm tmp/run')
    local('rm tmp/log_run')

def setup_config():
    """Sets up the various configuration files"""

    mode       = prompt('Mode:', default = 'live', validate = '^dev|live$')
    db_adapter = prompt(
        'Database adapter:',
        default  = 'postgres',
        validate = '^postgres|mysql2$'
    )

    db_user     = prompt('Database user:', validate = '^.+$')
    db_password = prompt('Database password:', validate = '^.+$')
    db_database = prompt('Database name:', validate = '^.+$')

    # Process each configuration file and upload it to the server.
    for config in env.config_files:
        dest = os.path.join(env.code_dir, 'config', '%s.rb' % config)
        tmp  = 'tmp/%s.rb' % config

        local('cp config/%s.default.rb %s' % (config, tmp))

        template = open(tmp, 'r').read().format(
            mode        = mode,
            db_adapter  = db_adapter,
            db_user     = db_user,
            db_password = db_password,
            db_database = db_database
        )

        open(tmp, 'w').write(template)
        put(tmp, dest)
        local("rm %s" % tmp)
