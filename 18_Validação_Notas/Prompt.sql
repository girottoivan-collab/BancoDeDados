Definições globais:

EA.TIPOSITTRIB = 'F' é igual a ST NORMAL-60
EA.TIPOSITTRIB = 'A' é igual a ST Fronteira = 60

Na tabela ESTOQUE_ANALITICO_FISCAL (EAF) onde a chave com a ESTOQUE_ANALITICO é IDEMPRESA, IDPLANILHA, NUMSEQUENCIA temos o EAF.FLAGTRIBUTACAOXML = 'T' que define se a tributação buscou do XML ou do Cadastro;

Em CLIENTE_FORNECEDOR (CF) temos CF.TIPOREGIMETRIBFEDERAL = 'S' que define se a tributação do cliente é Simples Nacional ou não;

Em CLIENTE_FORNECEDOR temos a atividade que define se o cliente é PRODUTOR ou não, vinculado a sua atividade. Consulta base abaixo:
SELECT CF.IDCLIFOR, CF.IDATIVIDADE, TA.DESCRTIPOATIVIDADE AS ATIVIDADE,
                ATV.FLAGPRODUTORRURAL AS PRODUTOR,
                CASE WHEN CF.TIPOREGIMETRIBFEDERAL = 'S' THEN 'S' ELSE 'N' END AS SIMPLESNACIONAL
        FROM DBA.CLIENTE_FORNECEDOR CF
        LEFT JOIN DBA.ATIVIDADE ATV ON ATV.IDATIVIDADE = CF.IDATIVIDADE
        LEFT JOIN DBA.ATIVIDADE_TIPO_ATIVIDADE ATA ON ATA.IDATIVIDADE = CF.IDATIVIDADE AND ATA.FLAGPADRAO = 'T'
        LEFT JOIN DBA.TIPO_ATIVIDADE TA ON TA.IDTIPOATIVIDADE = ATA.IDTIPOATIVIDADE;

As colunas que listarão na consulta serão:
IDCLIFOR	 IDATIVIDADE	 ATIVIDADE	 PRODUTOR	 TIPO	QTDNOTASTIPO	XML	CAD	% XML	% CAD;

Consultas a serem geradas:

Consulta 01: Fornecedor cadastrado como Produtor Rural, em que todas as notas lançadas no período utilizaram a tributação do cadastro, que apresentaram apenas um tipo de tributação, restrito aos CSTs 40, 41, 50, 90.
Consulta 02: Fornecedor cadastrado como Produtor Rural, em que todas as notas lançadas no período utilizaram a tributação do cadastro, que apresentaram mais de um tipo de tributação, restrito aos CSTs 40, 41, 50, 90.
Consulta 03: Fornecedor não cadastrado como Produtor Rural, em que todas as notas lançadas no período utilizaram a tributação do cadastro, que apresentaram apenas um tipo de tributação, restrito aos CSTs 40, 41, 50, 90.
Consulta 04: Fornecedor não cadastrado como Produtor Rural, em que todas as notas lançadas no período utilizaram a tributação do cadastro, que apresentaram mais de um tipo de tributação, restrito aos CSTs 40, 41, 50, 90.
Consulta 05: Fornecedor em que todas as notas lançadas no período utilizaram a tributação do cadastro, que apresentaram apenas um tipo de tributação, exceto os CSTs 40, 41, 50, 90.
Consulta 06: Fornecedor em que todas as notas lançadas no período utilizaram a tributação do cadastro, que apresentaram mais de um tipo de tributação, combinando CSTs 40, 41, 50 ou 90 com CSTs 00, 20, 51 ou 60.
Consulta 07: Fornecedor em que todas as notas lançadas no período utilizaram a tributação do XML, que apresentaram apenas um tipo de tributação, restrito aos CSTs 40, 41, 50, 90.
Consulta 08: Fornecedor em que todas as notas lançadas no período utilizaram a tributação do XML, que apresentaram mais de um tipo de tributação, restrito aos CSTs 40, 41, 50, 90.
Consulta 09: Fornecedor em que todas as notas lançadas no período utilizaram a tributação do XML, que apresentaram apenas um tipo de tributação, exceto os CSTs 40, 41, 50, 90.
Consulta 10: Fornecedor em que todas as notas lançadas no período utilizaram a tributação do XML, que apresentaram mais de um tipo de tributação, combinando CSTs 40, 41, 50 ou 90 com CSTs 00, 20, 51 ou 60.
Consulta 11: Fornecedor em que as notas lançadas no período utilizaram tributação do cadastro e do XML, que apresentaram apenas um tipo de tributação, exceto os CSTs 40, 41, 50, 90.
Consulta 12: Fornecedor em que as notas lançadas no período utilizaram tributação do cadastro e do XML, que apresentaram mais de um tipo de tributação, combinando CSTs 40, 41, 50 ou 90 com CSTs 00, 20, 51 ou 60.
Consulta 13: Fornecedor cadastrado como Simples Nacional, em que todas as notas lançadas no período utilizaram a tributação do cadastro, que apresentaram apenas um tipo de tributação, restrito aos CSTs 00, 20 ou 51.
Consulta 14: Fornecedor cadastrado como Simples Nacional, em que todas as notas lançadas no período utilizaram a tributação do cadastro, que apresentaram mais de um tipo de tributação, restrito aos CSTs 00, 20, ou 51.
Consulta 15: Fornecedor não cadastrado como Simples Nacional, em que todas as notas lançadas no período utilizaram a tributação do cadastro, que apresentaram apenas um tipo de tributação, restrito aos CSTs 00, 20 ou 51.
Consulta 16: Fornecedor não cadastrado como Simples Nacional, em que todas as notas lançadas no período utilizaram a tributação do cadastro, que apresentaram mais de um tipo de tributação, restrito aos CSTs 00, 20 ou 51.

Ao final, gere uma consulta onde una todas essas 16 consultas para termos uma comparação de total por tipo e comparar com a consulta base dos totais, ver se bate as informações, o número de notas.
