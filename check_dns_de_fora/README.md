# Monitorando consultas DNS externas com o Zabbix Agent 2

Em muitos ambientes, o servidor DNS é monitorado apenas sob a perspectiva da infraestrutura interna. Entretanto, isso não garante que clientes externos estejam conseguindo resolver nomes corretamente.

A proposta deste projeto é justamente realizar as consultas DNS a partir de um ponto externo à infraestrutura principal, simulando o comportamento de um cliente real. Dessa forma é possível identificar problemas de resolução que não seriam percebidos por verificações executadas dentro da própria rede.

O script foi desenvolvido de forma genérica, permitindo consultar qualquer servidor DNS, qualquer registro e qualquer domínio, tornando a solução flexível para diferentes cenários de monitoramento.

A integração com o Zabbix é realizada por meio de um UserParameter do Zabbix Agent 2, possibilitando que as consultas sejam executadas sob demanda pelo servidor ou proxy.

## Principais características

* Execução das consultas por um host externo à infraestrutura monitorada.
* Simulação da resolução DNS realizada por clientes reais.
* Compatível com qualquer servidor DNS.
* Suporte a diferentes tipos de registros (A, AAAA, MX, TXT, NS, CNAME, entre outros).
* Integração com o Zabbix Agent 2.
* Configuração através de macros, sem necessidade de alterar o script.

## Cenário recomendado

A ideia é instalar o agente em uma máquina localizada fora da rede principal — por exemplo:

* uma VPS;
* um servidor em outro datacenter;
* uma filial;
* um ambiente de homologação;
* ou qualquer ponto que represente a visão de um cliente externo.

Assim, o monitoramento deixa de validar apenas se o serviço DNS está ativo e passa a verificar se a resolução realmente funciona do ponto de vista de quem utiliza o serviço.

## Instalação

* [Procedimento de Instalação](INSTALACAO.md)
