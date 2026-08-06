# Plugin para monitoramento de Certificados de SSL

Este pluigin foi desenvolvido para atender a demanda de monitorar os certificados SSL em um ambiente de multiplos dominios em um unico webserver. 

O plugin faz a varredura nas configurações do Apache e/ou Nginx indentificando os certificados instalados e configura automaticamente na monitoria um dominio ativo na maquina na monitoria do Zabbix

## Ambientes validados

O pacote foi validado nos seguintes sistemas:

* Debian 11;
* Debian 12;
* Debian 13;

E nos seguintes Webservers:

* Apache2
* Nginx

No clientes foi testado com zabbix-agent e zabbix-agent2

Em todos os casos, os Webservers usados foram pacotes fornecidos pela própria distribuição, sem compilação manual ou substituição por versão externa ao repositório do sistema operacional.

## Instalação

  Após baixar os arquivos do git com o comando :

```
git clone git@github.com:jemorenojr/Zabbix_Plugins.git
```

Entrar no diretorio dos arquivos do plugin :

```
cd Zabbix_Plugins\Certificados_SSL
sudo install -d /usr/local/zabbix/scripts/
sudo install -m 755 -o zabbix -D ssl_vhosts_discovery.sh /usr/local/zabbix/scripts/
sudo install -m 644 -o zabbix -D webserver_ssl_discovery.conf /etc/zabbix/zabbix_agent2.d/plugins.d
```

> **Observação:** Ajustar o diretorio de configuração do do agent do zabbix , de acordo com a versão que esta usando , para o zabbix-agent o diretório seria ```/etc/zabbix/zabbix_agentd.conf.d/plugins.d```

E reiniciar o serviço do zabbix-agent

```
systemctl restart zabbix-agent2.service
```
Na inetrface GUI do Zabbix Server, importar o template Webserver_SSL_Certificates_Discovery.yaml 

[Gui_importacao_template_ssl.png](https://github.com/jemorenojr/Zabbix_Plugins/blob/ac62b0879eb8fe80db7691f28c61340cedc2ef27/Certificados_SSL/Gui_importacao_template_ssl.png)

## Configurações 

O script faz a busca nos diretorios padrões do apache e do nginx , então a principio não necessita de configurações.

## Documentação de componentes

* [Script ssl_vhosts_discovery.sh](ssl_vhosts_discovery.sh): script de busca de certificados instalados no webserver.
* [Conf webserver_ssl_discovery.conf](webserver_ssl_discovery.conf): configuração do script de busca no zabbi-agent, ele permite que os parametros sejam disponibilizados corretamente para zabbix server
* [Template Zabbix Webserver_SSL_Certificates_Discovery.yaml](Webserver_SSL_Certificates_Discovery.yaml): Template do Webserver SSL Certificates Discovery para o zabbix server
