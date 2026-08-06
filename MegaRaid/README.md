# Monitoramento de controladoras MegaRAID no Zabbix

Este conjunto de scripts e template permite identificar automaticamente servidores que possuem controladoras RAID compatíveis com **MegaRAID/MegaCli** e habilitar o monitoramento correspondente no Zabbix.

A proposta é evitar a associação manual de itens específicos de MegaRAID a todos os servidores. O discovery verifica primeiro se o equipamento possui uma controladora suportada e fornece ao Zabbix as informações necessárias para criar os itens de monitoramento.

## Funcionamento

O processo é dividido em duas etapas:

```text
Zabbix Agent
    |
    +-- check_megaraid_discovery_zabbix.sh
    |       |
    |       +-- localiza lspci
    |       +-- procura controladora MegaRAID
    |       +-- localiza MegaCli/MegaCli64
    |       +-- gera JSON para LLD
    |
    +-- check_megaraid_zabbix.sh
            |
            +-- discos físicos
            +-- volumes RAID
            +-- bateria
```

O script de discovery utiliza `lspci` para identificar controladoras compatíveis com MegaRAID, procurando referências a LSI, Broadcom, Avago ou MegaRAID.

Quando nenhuma controladora é encontrada, o discovery retorna:

```json
{"data":[]}
```

Dessa forma, hosts sem esse hardware simplesmente não recebem os itens específicos de MegaRAID.

## Detecção do MegaCli

O discovery também procura automaticamente pelo utilitário MegaCli.

São considerados:

```text
MEGACLI_BIN
/opt/MegaRAID/MegaCli/MegaCli64
MegaCli
MegaCli64
megacli
megacli64
```

A variável `MEGACLI_BIN` pode ser utilizada para informar explicitamente a localização do executável.

A disponibilidade do utilitário também pode ser consultada através de:

```bash
check_megaraid_discovery_zabbix.sh --check megacli
```

Retornos:

```text
1 - MegaCli disponível
0 - MegaCli não encontrado
```

Isso permite que o próprio Zabbix alerte quando uma controladora MegaRAID foi identificada, mas a ferramenta necessária para sua coleta não está instalada.

## Low-Level Discovery

Quando uma controladora é encontrada, o script retorna um objeto LLD contendo:

```text
{#MEGARAID}
{#MEGARAID_MODEL}
{#MEGACLI_BIN}
{#MEGACLI_AVAILABLE}
```

Exemplo conceitual:

```json
{
  "data": [
    {
      "{#MEGARAID}": "megaraid",
      "{#MEGARAID_MODEL}": "...",
      "{#MEGACLI_BIN}": "/opt/MegaRAID/MegaCli/MegaCli64",
      "{#MEGACLI_AVAILABLE}": "1"
    }
  ]
}
```

Essas macros são utilizadas pelo template para criar os elementos de monitoramento somente nos hosts onde a controladora foi detectada.

## UserParameters

O arquivo `megaraid.conf` define os UserParameters utilizados pelo Zabbix Agent:

```ini
UserParameter=megaraid.discovery,/usr/local/zabbix/scripts/check_megaraid_discovery_zabbix.sh
UserParameter=megaraid.megacli.available[*],/usr/local/zabbix/scripts/check_megaraid_discovery_zabbix.sh --check megacli
UserParameter=megaraid.discos[*],/usr/local/zabbix/scripts/check_megaraid_zabbix.sh -c discos
UserParameter=megaraid.raid[*],/usr/local/zabbix/scripts/check_megaraid_zabbix.sh -c raid
UserParameter=megaraid.bateria[*],/usr/local/zabbix/scripts/check_megaraid_zabbix.sh -c bateria
```

Os caminhos devem ser ajustados conforme a instalação local.

## Arquivos

```text
MegaRaid/
├── check_megaraid_discovery_zabbix.sh
├── check_megaraid_zabbix.sh
├── megaraid.conf
└── MegaRAID_templates.yaml
```

### `check_megaraid_discovery_zabbix.sh`

Responsável pela descoberta da controladora e pela localização do MegaCli.

### `check_megaraid_zabbix.sh`

Responsável pela coleta do estado dos componentes MegaRAID utilizados pelos UserParameters de discos, volumes RAID e bateria.

### `megaraid.conf`

Configuração dos UserParameters do Zabbix Agent.

### `MegaRAID_templates.yaml`

Template para importação no Zabbix contendo o discovery, itens e triggers relacionados ao monitoramento.

## Dependências

No mínimo:

```text
lspci
Zabbix Agent
```

Para a coleta efetiva das informações da controladora:

```text
MegaCli ou MegaCli64
```

O discovery continua funcionando sem MegaCli. Nesse caso, a controladora pode ser identificada e o Zabbix poderá indicar que a ferramenta de coleta está ausente.

## Instalação

Copie os scripts para o diretório utilizado pelo Zabbix:

```bash
mkdir -p /usr/local/zabbix/scripts
cp check_megaraid*.sh /usr/local/zabbix/scripts/
chmod 755 /usr/local/zabbix/scripts/check_megaraid*.sh
```

Instale `megaraid.conf` no diretório de configurações adicionais do Agent, ajustando os caminhos se necessário.

Reinicie o Zabbix Agent após a alteração.

Antes de importar o template, o discovery pode ser validado diretamente:

```bash
/usr/local/zabbix/scripts/check_megaraid_discovery_zabbix.sh
```

Em um servidor sem controladora compatível, o resultado esperado é:

```json
{"data":[]}
```

Em um servidor com MegaRAID, será retornado o JSON LLD contendo a identificação da controladora.

Também é possível testar:

```bash
/usr/local/zabbix/scripts/check_megaraid_discovery_zabbix.sh --check megacli
```

## Considerações

A detecção foi construída para controladoras identificadas pelo `lspci` como MegaRAID ou controladoras RAID associadas a LSI, Broadcom e Avago.

A compatibilidade efetiva da coleta depende da controladora e da versão do MegaCli disponível no sistema.

O objetivo do discovery não é substituir as ferramentas de gerenciamento do fabricante, mas permitir que informações importantes sobre o estado do RAID sejam incorporadas ao monitoramento centralizado do Zabbix.

## Licença e uso

O código pode ser adaptado aos caminhos, versões de MegaCli e políticas de monitoramento de cada ambiente.