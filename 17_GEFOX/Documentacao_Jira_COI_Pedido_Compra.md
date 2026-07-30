# Ajuste de validacao do COI no pedido de compra

## Resumo para o Jira

Foi criada uma melhoria na rotina de gravacao de pedido de compra para validar o `IDOPERACAO` utilizado no pedido conforme os bloqueios de COI por empresa.

A alteracao foi entregue em um novo script V2, sem alterar o arquivo original da procedure:

- `17_GEFOX/SP_INSERT_PEDIDO_COMPRA_NEW_29072026.sql`

## Contexto

A procedure `DBA.SP_INSERT_PEDIDO_COMPRA` definia o `IDOPERACAO` do pedido de compra usando a seguinte prioridade:

1. `DBA.CLIENTE_FORNECEDOR.IDOPERACAOPADRAO`, quando informado para o fornecedor.
2. `DBA.CONFIG_COMPRAS.IDCOIPADRAOPEDIDOCOMPRA`, quando nao havia COI no fornecedor.
3. Codigo `1`, como fallback.

Essa regra nao considerava a tabela `DBA.EMPRESA_BLOQUEIO_COI`. Quando existe registro nessa tabela para a combinacao `IDEMPRESA` + `IDOPERACAO`, a operacao esta bloqueada para a empresa e nao deve ser usada no pedido.

## Alteracao realizada

Foi criada a function:

```sql
DBA.UF_GET_COI_PEDIDO_COMPRA_LIBERADO(AI_IDEMPRESA, AI_IDCLIFOR)
```

Essa function centraliza a escolha do COI valido para o pedido de compra, avaliando se a operacao esta liberada para a empresa antes de retornar o `IDOPERACAO`.

A procedure `DBA.SP_INSERT_PEDIDO_COMPRA` no script V2 passou a usar:

```sql
SET AI_OPERACAOINTERNA = DBA.UF_GET_COI_PEDIDO_COMPRA_LIBERADO(AI_IDEMPRESA, AI_IDCLIFOR);
```

O restante da logica de insert/update do pedido foi preservado.

## Regra de negocio implementada

A function aplica a seguinte hierarquia:

1. Busca o COI padrao do fornecedor em `DBA.CLIENTE_FORNECEDOR.IDOPERACAOPADRAO`.
2. Se o COI do fornecedor estiver bloqueado para a empresa em `DBA.EMPRESA_BLOQUEIO_COI`, busca o COI padrao geral em `DBA.CONFIG_COMPRAS.IDCOIPADRAOPEDIDOCOMPRA`.
3. Se o COI da configuracao geral tambem estiver bloqueado para a empresa, busca a menor operacao liberada na tabela `DBA.OPERACAO_INTERNA`.

Em todos os niveis, a operacao precisa existir em `DBA.OPERACAO_INTERNA` com:

```sql
TIPOCATEGORIA = 'C'
TIPOITEMCATEGORIA = 'C1'
```

E nao pode possuir bloqueio na tabela:

```sql
DBA.EMPRESA_BLOQUEIO_COI
```

Para a ultima alternativa, e retornado:

```sql
MIN(DBA.OPERACAO_INTERNA.IDOPERACAO)
```

considerando apenas operacoes de compra `C/C1` liberadas para a empresa.

## Impacto funcional

- Pedidos de compra deixam de ser gravados com COI bloqueado para a empresa.
- A escolha do COI passa a respeitar a parametrizacao de bloqueio por empresa.
- A regra existente de prioridade fornecedor > configuracao geral foi mantida.
- Foi adicionado um novo fallback mais seguro: menor COI de compra liberado para a empresa.
- A alteracao reduz risco de rejeicoes, inconsistencias ou necessidade de correcao manual quando o COI padrao estiver bloqueado.

## Impacto tecnico

- Criacao da function `DBA.UF_GET_COI_PEDIDO_COMPRA_LIBERADO`.
- Alteracao da procedure `DBA.SP_INSERT_PEDIDO_COMPRA` apenas no ponto de definicao da variavel `AI_OPERACAOINTERNA`.
- Remocao das variaveis locais que eram usadas somente para montar o `COALESCE` anterior:
	- `AI_IDOPERACAO`
	- `AI_IDOPERCLIFOR`
- Mantidos os grants para o usuario `GEA`.
- O arquivo original `SP_INSERT_PEDIDO_COMPRA_NEW_16072026.txt` foi preservado sem alteracao.

## Objetos envolvidos

- `DBA.SP_INSERT_PEDIDO_COMPRA`
- `DBA.UF_GET_COI_PEDIDO_COMPRA_LIBERADO`
- `DBA.CLIENTE_FORNECEDOR`
- `DBA.CONFIG_COMPRAS`
- `DBA.OPERACAO_INTERNA`
- `DBA.EMPRESA_BLOQUEIO_COI`
- `DBA.PEDIDO_COMPRA`

## Cenario antes da alteracao

Caso o fornecedor ou a configuracao geral possuisse um COI bloqueado para a empresa, a procedure ainda poderia gravar esse `IDOPERACAO` no pedido de compra.

## Cenario depois da alteracao

Antes de gravar o pedido, a procedure chama a function de validacao. A function verifica a hierarquia e retorna somente um COI de compra liberado para a empresa.

## Roteiro sugerido de validacao

1. Identificar uma empresa com bloqueio cadastrado em `DBA.EMPRESA_BLOQUEIO_COI`.
2. Configurar um fornecedor com `IDOPERACAOPADRAO` bloqueado para essa empresa.
3. Garantir que `DBA.CONFIG_COMPRAS.IDCOIPADRAOPEDIDOCOMPRA` esteja liberado.
4. Executar a gravacao de pedido e confirmar que `DBA.PEDIDO_COMPRA.IDOPERACAO` recebeu o COI da configuracao geral.
5. Bloquear tambem o COI da configuracao geral para a mesma empresa.
6. Executar nova gravacao de pedido e confirmar que `DBA.PEDIDO_COMPRA.IDOPERACAO` recebeu a menor operacao `C/C1` liberada para a empresa.
7. Testar um fornecedor com COI liberado e confirmar que a prioridade do fornecedor foi mantida.

## Consultas auxiliares

Validar se uma operacao esta bloqueada para uma empresa:

```sql
SELECT
	*
FROM
	DBA.EMPRESA_BLOQUEIO_COI
WHERE
	IDEMPRESA = <IDEMPRESA> AND
	IDOPERACAO = <IDOPERACAO>;
```

Listar operacoes de compra liberadas para uma empresa:

```sql
SELECT
	OI.IDOPERACAO,
	OI.TIPOCATEGORIA,
	OI.TIPOITEMCATEGORIA
FROM
	DBA.OPERACAO_INTERNA OI
WHERE
	OI.TIPOCATEGORIA = 'C' AND
	OI.TIPOITEMCATEGORIA = 'C1' AND
	NOT EXISTS (
		SELECT
			1
		FROM
			DBA.EMPRESA_BLOQUEIO_COI EBC
		WHERE
			EBC.IDEMPRESA = <IDEMPRESA> AND
			EBC.IDOPERACAO = OI.IDOPERACAO
	)
ORDER BY
	OI.IDOPERACAO;
```

Validar retorno da function:

```sql
VALUES DBA.UF_GET_COI_PEDIDO_COMPRA_LIBERADO(<IDEMPRESA>, <IDCLIFOR>);
```

## Observacoes para implantacao

- Aplicar o script `17_GEFOX/SP_INSERT_PEDIDO_COMPRA_NEW_29072026.sql`.
- A function deve ser criada antes da procedure, pois a procedure depende dela.
- O script V2 ja contem `GRANT EXECUTE` da function e da procedure para o usuario `GEA`.
- Recomenda-se validar em base de teste antes da promocao para producao.
