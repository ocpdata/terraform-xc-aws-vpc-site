output "site_name" {
  description = "Name of the configured AWS VPC Site."
  value       = module.aws_vpc_site.name
}

output "site_id" {
  description = "ID of the configured AWS VPC Site."
  value       = module.aws_vpc_site.id
}

output "master_public_ip_address" {
  description = "Ip address of the master node."
  value       = try(module.aws_vpc_site.apply_tf_output_map.master_public_ip_address, null)
}

output "ssh_private_key" {
  description = "AWS VPC Site generated private key."
  value       = module.aws_vpc_site.ssh_private_key_openssh
  sensitive   = true
}

output "ssh_public_key" {
  description = "AWS VPC Site public key."
  value       = module.aws_vpc_site.ssh_public_key
}

output "vpc_id" {
  value       = module.aws_vpc_site.vpc_id
  description = "The ID of the VPC."
}

output "local_subnet_ids" {
  value       = module.aws_vpc_site.local_subnet_ids
  description = "List of local subnet IDs."
}

output "http_loadbalancer_name" {
  description = "Nombre del HTTP Load Balancer en F5 XC."
  value       = volterra_http_loadbalancer.nginx.name
}

output "http_loadbalancer_namespace" {
  description = "Namespace del HTTP Load Balancer en F5 XC."
  value       = volterra_http_loadbalancer.nginx.namespace
}

output "how_to_test" {
  description = "Instrucciones para desplegar nginx y probar el Load Balancer."
  value       = <<-EOT
    1. Espera a que el site esté ONLINE en F5 XC Console.
    2. Descarga el kubeconfig: Console > Cloud & Edge Sites > Sites > aws-example-app-stack > K8s > Download kubeconfig
    3. Despliega nginx:
         KUBECONFIG=<ruta_kubeconfig> kubectl apply -f k8s/nginx-demo.yaml
    4. Obtén el CNAME del LB: Console > App Delivery > Load Balancers > HTTP Load Balancers > nginx-demo-lb
    5. Prueba: curl -H 'Host: nginx-demo.example.com' http://<CNAME>/
  EOT
}
