properties([
        parameters(
                [
                        stringParam(
                                name: 'GIT_REPO',
                                defaultValue: 'k8s-datagram'
                        ),
                        stringParam(
                                name: 'VERSION',
                                defaultValue: '0.1.0'
                        ),
                        choiceParam(
                                name: 'ENV',
                                choices: ['datagram']
                        )
                ]
        )
])

pipeline {

    agent {
        kubernetes {
            label 'deploy-service-pod'
            defaultContainer 'jnlp'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    job: deploy-service
spec:
  containers:
  - name: git
    image: alpine/git
    command: ["cat"]
    tty: true
  - name: helm-cli
    image: lachlanevenson/k8s-helm
    command: ["cat"]
    tty: true
"""
        }
    }

    stages {

        stage('Find deployment descriptor') {
            steps {
                container('git') {
                    script {
//                         def revision = params.VERSION.substring(0, 7)
//                         def revision = 0.1.0
                        withCredentials([[
                                $class: 'UsernamePasswordMultiBinding',
                                credentialsId: 'rmusin',
                                usernameVariable: 'USERNAME',
                                passwordVariable: 'PASSWORD'
                        ]]) {
                            sh "git clone https://github.com/zanzibeer/jenkins.git"
//                             dir ("${params.GIT_REPO}") {
//                                 sh "git checkout ${revision}"
//                             }
                        }
                    }
                }
            }
        }
        stage('Deploy to env') {
            steps {
                container('helm-cli') {
                    script {
                        dir ("${params.GIT_REPO}") {
//                             sh "./helm/setRevision.sh ${params.VERSION}"
//                             def registryIp = sh(script: 'getent hosts registry.kube-system | awk \'{ print $1 ; exit }\'', returnStdout: true).trim()
//                             sh "helm dependency build helm/datagram"
//                             sh "sleep 100"
                            sh 'helm upgrade ${params.ENV} helm/datagram --install --namespace ${params.ENV} --set postgresql.auth.password="chAngE_Me"'
                        }
                    }
                }
            }
        }
    }
}