from fabric.api     import *
from fabric_modules import common
from fabric_modules import runit

env.hosts          = ['yorickpeterse@stewie.yorickpeterse.com']
env.deployment_dir = '/home/yorickpeterse/domains/yorickpeterse.com'
env.repository     = 'git://github.com/YorickPeterse/yorickpeterse.com.git'
env.config_files   = ['config', 'database', 'unicorn']

# Configuration for Runit related commands
env.service_dir  = '/home/yorickpeterse/service/yorickpeterse.com'
env.run_template = 'fabric_modules/templates/runit/run'
env.log_template = 'fabric_modules/templates/runit/log/run'

@task
def deploy():
    """Updates the Git repository and deploys the website."""

    local('git checkout master')
    local('git push origin master')

    update()

@task
def setup():
    """Sets up the required files and folders on remote servers."""

    run('mkdir -p %s' % env.deployment_dir)

    with cd(env.deployment_dir):
        run('git init && git remote add origin %s' % env.repository)
        run('git pull origin master')

    install_gems()
    common.configure()
    runit.setup()

    with cd(env.deployment_dir):
        run('rake db:migrate')

    run('sv start %s' % env.service_dir)

def update():
    """Updates the application."""

    run('sv d %s' % env.service_dir)

    with cd(env.deployment_dir):
        run('git pull origin master && git reset --hard')
        run('rake db:migrate')

    run('sv start %s' % env.service_dir)

@task
def install_gems():
    """Installs all the gems defined in the .gems file"""

    with cd(env.deployment_dir):
        run('`cat .rvmrc` && rvm gemset import .gems')
