pipeline {
    agent {
        label 'terraform-aws'
    }

    environment {
        AWS_REGION             = 'us-west-2'
        TF_VERSION            = '1.5.0'
        TF_IN_AUTOMATION      = 'true'
        TF_INPUT              = 'false'
        KUBE_VERSION          = '1.28'
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }

    stages {
        stage('Checkout & Setup') {
            steps {
                checkout scm
                sh 'terraform --version'
                sh 'aws --version'
                sh 'kubectl version --client'
            }
        }

        stage('Terraform Init') {
            steps {
                dir('modules/vpc') {
                    sh 'terraform init -backend=false -no-color'
                }
                dir('modules/eks') {
                    sh 'terraform init -backend=false -no-color'
                }
                dir('modules/iam') {
                    sh 'terraform init -backend=false -no-color'
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                script {
                    def dirs = findFiles(glob: 'modules/**/main.tf').collect {
                        it.path.split('/')[1]
                    }.unique()

                    dirs.each { dir ->
                        dir("modules/${dir}") {
                            sh 'terraform validate -no-color'
                        }
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'AWS_CREDENTIALS',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                    terraform plan \
                        -var="aws_region=${AWS_REGION}" \
                        -var="cluster_version=${KUBE_VERSION}" \
                        -out=tfplan \
                        -no-color
                    '''
                }
            }
        }

        stage('Security Scan') {
            steps {
                sh 'terraform show -no-color tfplan > tfplan.txt'
                sh 'checkov -f tfplan.txt --skip-check CKV_AWS_58,CKV_AWS_88 --soft-fail'
            }
        }

        stage('Manual Approval') {
            when {
                branch 'main'
            }
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    input message: 'Approve Terraform Apply?', ok: 'Deploy'
                }
            }
        }

        stage('Terraform Apply') {
            when {
                anyOf {
                    branch 'main'
                    triggeredBy 'TimerTrigger'
                }
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'AWS_CREDENTIALS',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh 'terraform apply -auto-approve -no-color tfplan'
                }
            }
        }

        stage('Kubeconfig Setup') {
            steps {
                script {
                    def cluster_name = sh(
                        script: 'terraform output -raw cluster_name',
                        returnStdout: true
                    ).trim()

                    sh """
                    aws eks update-kubeconfig \
                        --name ${cluster_name} \
                        --region ${AWS_REGION}
                    """
                }
            }
        }

        stage('Smoke Test') {
            steps {
                sh 'kubectl get nodes --no-headers | wc -l > node_count.txt'
                script {
                    def node_count = readFile('node_count.txt').trim()
                    if (node_count.toInteger() < 1) {
                        error('Cluster health check failed: No worker nodes available')
                    }
                }
                sh 'kubectl cluster-info'
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '**/tfplan*', allowEmptyArchive: true
            junit '**/terraform-test-report.xml'
        }
        success {
            slackSend color: 'good', message: "EKS Deployment Successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        }
        failure {
            slackSend color: 'danger', message: "EKS Deployment Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        }
    }
}