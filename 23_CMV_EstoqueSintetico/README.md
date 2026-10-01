# CISS-183841 — Reprocessamento de CMV por alteração de estoque

## Objetivo

Permitir que o processador de CMV identifique empresa e dia cujo estoque tenha
sofrido inclusão ou alteração posterior ao processamento contábil. Assim, o próprio
processador poderá alterar o status da fila e reprocessar o CMV necessário.

## Cenário atual

O CMV é apurado diariamente por empresa a partir da tabela
`DBA.ESTOQUE_SINTETICO`. O processamento é controlado por
`DBA.CONTABIL_PROCESSAMENTO_CMV`, cuja PK é `IDPLANILHA` e que possui unicidade
por `IDEMPRESA` e `DTPROCESSAMENTO`. O `IDPLANILHA` representa o lançamento
contábil gerado.

Notas retroativas e alterações em dados que influenciam o custo médio podem alterar
o CMV de uma data já processada. Como a tabela de estoque não guarda o instante da
última alteração, atualmente não há como identificar de forma incremental quais
dias devem ser reprocessados.

## Solução proposta

Adicionar uma marca temporal à `DBA.ESTOQUE_SINTETICO` e mantê-la automaticamente
por gatilhos. A marcação será usada exclusivamente para o processador localizar
empresa/dia alterados; a consulta atual de cálculo de CMV não precisa ser alterada.

Registros existentes antes da implantação devem permanecer com a nova coluna nula.
Com isso, somente inclusões e alterações posteriores à implantação integram a
varredura incremental, sem provocar reprocessamento de todo o histórico.

## Objetos alterados e criados

| Ação | Tipo | Nome | Definição / finalidade |
| --- | --- | --- | --- |
| Alterar | Coluna | `DBA.ESTOQUE_SINTETICO.DTALTERACAO` | Coluna `TIMESTAMP`, anulável e sem `DEFAULT`. Armazena o momento da última inclusão ou alteração feita após a implantação. |
| Criar | Trigger | `DBA.TR_ESTSIN_DTALTERACAO_BI` | `NO CASCADE BEFORE INSERT`, por linha. Define `NEW.DTALTERACAO = CURRENT TIMESTAMP` em toda nova linha de estoque. |
| Criar | Trigger | `DBA.TR_ESTSIN_DTALTERACAO_BU` | `NO CASCADE BEFORE UPDATE`, por linha. Atualiza `NEW.DTALTERACAO = CURRENT TIMESTAMP` em qualquer alteração da linha. |
| Criar | Trigger | `DBA.TR_ESTSIN_CMV_AD` | `AFTER DELETE`, por linha. Altera para Pendente a fila da mesma empresa e da própria data excluída. |
| Criar | Índice | `DBA.IX_ESTSIN_DTALT_EMP_DT` | Índice em `(DTALTERACAO, IDEMPRESA, DTMOVIMENTO)` para busca eficiente das empresas/dias alterados dentro da janela incremental. |

Os gatilhos `BEFORE` carimbam a data antes do fluxo já existente de cálculo de
custo médio. Eles não alteram a chave da tabela, o cálculo de CMV, o lançamento
contábil nem a regra de unicidade da fila de processamento. O gatilho de exclusão
altera apenas o status da fila da própria data excluída.

## Uso pelo processador

O processador deverá manter uma marca d'água do último consumo bem-sucedido. Em
cada execução, deve obter as empresas e datas que tenham `DTALTERACAO` dentro da
janela de leitura:

```sql
SELECT IDEMPRESA,
       DTMOVIMENTO,
       MAX(DTALTERACAO) AS ULTIMA_ALTERACAO
  FROM DBA.ESTOQUE_SINTETICO
 WHERE DTALTERACAO > :ultima_marca_dagua
   AND DTALTERACAO <= :limite_janela
 GROUP BY IDEMPRESA, DTMOVIMENTO
 ORDER BY IDEMPRESA, DTMOVIMENTO;
```

Para cada empresa/data retornada, o processador deve atualizar o status do registro
já existente em `DBA.CONTABIL_PROCESSAMENTO_CMV` e executar novamente a apuração
de CMV. Não deve inserir uma nova fila para o mesmo par empresa/data, preservando a
regra de unicidade já definida.

O CMV é cumulativo por empresa e dia. Portanto, quando identificar uma alteração em
uma data retroativa, o reprocessador deverá, além da data afetada, verificar e
reabrir para reprocessamento todas as datas posteriores já processadas da mesma
empresa. Essa propagação é responsabilidade do reprocessador e não é realizada
pelos gatilhos.

A marca d'água só deve avançar após o tratamento persistir com sucesso todas as
chaves da janela. O limite superior da janela deve ser capturado no início da
execução, evitando a perda de alterações ocorridas durante o processamento.

## Tratamento de exclusões

Uma linha removida não pode reter seu próprio `DTALTERACAO`. Por isso,
`DBA.TR_ESTSIN_CMV_AD` executa após a exclusão e atualiza somente o registro de
`DBA.CONTABIL_PROCESSAMENTO_CMV` da mesma empresa e da própria data excluída,
alterando `TPSTATUS` para `0`, que corresponde a **Pendente**. O campo é numérico;
o status lógico `P` não é gravado literalmente.

O gatilho não reabre períodos posteriores. Como o CMV é cumulativo, o
reprocessador deverá identificar e reabrir as datas posteriores aplicáveis da mesma
empresa, tanto para exclusões quanto para inclusões ou atualizações retroativas.
