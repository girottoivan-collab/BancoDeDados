CREATE OR REPLACE FUNCTION INTEGRIM.SET_ITEM_PEDIDO_INTEGRIN_V2(
    IN_IDPEDIDO                 INTEGER,
    IN_IDEMPRESA                INTEGER,
    IN_IDVENDEDOR               INTEGER,
    IN_IDPRODUTO                INTEGER,
    IN_IDSUBPRODUTO             INTEGER,
    IN_NUMSEQUENCIA             INTEGER,
    IN_IDLOTE                   VARCHAR(30),
    IN_QTDPRODUTO               DECIMAL(12,3),
    IN_VALUNITBRUTO             DECIMAL(15,6),
    IN_VALTOTLIQUIDO            DECIMAL(14,2),
    IN_VALDESCONTOPRO           DECIMAL(15,6),
    IN_VALDESCONTOFINANCEIRO    DECIMAL(14,2),
    IN_VALACRESCIMOPRO          DECIMAL(15,6),
    IN_VALACRESCIMOFINANCEIRO   DECIMAL(14,2),
    IN_TIPOENTREGA              CHAR(1),
    IN_PERCOMISSAO              DECIMAL(15,6),
    IN_IDLOCALRETIRADAENTREGA   INTEGER,
    IN_IDLOCALRETIRADA          INTEGER,
    IN_VALFRETE                 DECIMAL(15,6)
)
RETURNS TABLE (
    STATUSITENSPEDIDO    INTEGER
) LANGUAGE SQL
MODIFIES SQL DATA
BEGIN ATOMIC
    DECLARE STATUSITENSPEDIDO       INTEGER DEFAULT 0;
    DECLARE HOUVEALTERACAO          INTEGER DEFAULT 0;
    DECLARE LI_IDCONTADORRESERVA    INTEGER;
    DECLARE LI_IDLOCALESTOQUE       INTEGER;
    DECLARE LC_TIPOBAIXAMESTRE      CHAR(1);
    DECLARE LC_TIPOPEDIDO           CHAR(1);
    DECLARE LC_TIPODOCUMENTO        CHAR(1);
    DECLARE LC_ORIGEMRESERVA        CHAR(1);
    DECLARE LI_IDOPERACAO           INTEGER;
    DECLARE LS_IDLOTE               VARCHAR(30);
    DECLARE LI_IDCLIFOR             INTEGER;
    DECLARE LI_UTILIZACENARIO       INTEGER;
    DECLARE LI_IDCENARIOPROD        INTEGER DEFAULT NULL;
    DECLARE CEN_UFORIGEM            CHAR(2);
    DECLARE CEN_UFDESTINO           CHAR(2);
    DECLARE CEN_TPTRIBORIGEM        CHAR(1);
    DECLARE CEN_TPTRIBDESTINO       CHAR(1);
    DECLARE CEN_ATVORIGEM           INTEGER;
    DECLARE CEN_ATVDESTINO          INTEGER;
    DECLARE LD_PERDESCONTO          DECIMAL(14,6);
    SET LI_UTILIZACENARIO = COALESCE((
                            SELECT
                                COUNT(0) as CENARIO
                            FROM (  SELECT
                                        CASE
                                            WHEN coalesce((SELECT Dados From DBA.Config_Entidade Where Entidade = 'SGC' and Chave1 = 1000 and Chave2 = 3000),'F') = 'T'
                                            THEN 'P'
                                            WHEN coalesce((SELECT Dados From DBA.Config_Entidade Where Entidade = 'SGC' and Chave1 = 1000 and Chave2 = 4000),'F') = 'T'
                                            THEN 'I'
                                            WHEN (coalesce((SELECT Dados From DBA.Config_Entidade Where Entidade = 'SGC' and Chave1 = 1000 and Chave2 = 3000),'F') = 'F' AND
                                                 coalesce((SELECT Dados From DBA.Config_Entidade Where Entidade = 'SGC' and Chave1 = 1000 and Chave2 = 4000),'F') = 'F')
                                            THEN 'N'
                                            END UtilizaCenarioFiscal
                                    FROM
                                        DBA.DUMMY) TEMP
                            WHERE
                                TEMP.UtilizaCenarioFiscal <> 'N'),0);
    SET (LI_IDCLIFOR,LC_TIPOPEDIDO,LC_ORIGEMRESERVA,LC_TIPODOCUMENTO,LI_IDOPERACAO) =
    (
    SELECT
        IDCLIFOR,
        CASE
            WHEN FLAGPRENOTA = 'T' THEN
                'P'
            ELSE
                'O'
        END AS TIPOPEDIDO,
        CASE
            WHEN FLAGPRENOTA = 'T' THEN
                'P'
            ELSE
                'O'
        END AS ORIGEMRESERVA,
        CASE
            WHEN FLAGPRENOTA = 'T' THEN
                'X'
            ELSE
                'O'
        END AS TIPODOCUMENTO
        ,
        CASE
            WHEN FLAGPRENOTA = 'T' THEN
                3000
            ELSE
                1001
        END AS IDOPERACAO
    FROM
        DBA.ORCAMENTO ORCAMENTO
    WHERE
        ORCAMENTO.IDEMPRESA = IN_IDEMPRESA AND
        ORCAMENTO.IDORCAMENTO = IN_IDPEDIDO
    );
    --VALIDACAO IGUAL AO DO TELE-VENDAS PARA NAO PERMITIR ACRESCIMO E DESCONTO JUNTOS
    IF IN_VALDESCONTOPRO <> 0 AND IN_VALACRESCIMOPRO <> 0 THEN
        SIGNAL SQLSTATE '75000' SET MESSAGE_TEXT='Desconto não pode ser calculado pois possui acrescimo no produto atual';
    END IF;
    --NO TELEVENDAS - TELA DE PAGAMENTO AO UTILIZAR UMA FORMA DE PAGAMENTO COM ACRESCIMO E JA POSSUIR DESCONTO FINANCEIRO
    IF IN_VALDESCONTOFINANCEIRO <> 0 AND IN_VALACRESCIMOFINANCEIRO <> 0 THEN
        SIGNAL SQLSTATE '75000' SET MESSAGE_TEXT='Nao sera possivel utilizar formas de pagamento com acrescimo quando existir desconto informado';
    END IF;
    IF LI_IDCLIFOR IS NULL THEN
        SIGNAL SQLSTATE '75000' SET MESSAGE_TEXT='Pedido não registrado na base de dados';
    END IF;
    SET LC_TIPOBAIXAMESTRE = (SELECT TIPOBAIXAMESTRE FROM DBA.PRODUTO WHERE IDPRODUTO = IN_IDPRODUTO);
    IF LC_TIPOBAIXAMESTRE IS NULL THEN
        SIGNAL SQLSTATE '75000' SET MESSAGE_TEXT='Produto inválido ou não cadastrado';
    END IF;
    IF ((IN_QTDPRODUTO <= 0) OR  (IN_VALUNITBRUTO <= 0) OR (IN_VALTOTLIQUIDO <= 0)) THEN
        SIGNAL SQLSTATE '75000' SET MESSAGE_TEXT='Quantidade e ou valor unitario deverão ser superior a 0';
    END IF;
    SET LI_IDLOCALESTOQUE = (SELECT IDLOCALESTOQUE FROM DBA.LOCAL_RETIRADA WHERE IDLOCALRETIRADA = IN_IDLOCALRETIRADA);
    IF TRIM(IN_IDLOTE) <> '' THEN
        SET LS_IDLOTE = IN_IDLOTE;
    END IF;
    IF LI_UTILIZACENARIO <> 0 AND LI_IDCLIFOR IS NOT NULL THEN
        SET (   CEN_UFORIGEM,
                CEN_UFDESTINO,
                CEN_TPTRIBORIGEM,
                CEN_TPTRIBDESTINO,
                CEN_ATVORIGEM,
                CEN_ATVDESTINO ) =
                                  ( SELECT
                                        EMP.UF UFORIGEM,
                                        ORC.UF UFDESTINO,
                                        EMP.TIPOREGIMETRIBFEDERAL AS TPTRIBORIGEM,
                                        CLI.TIPOREGIMETRIBFEDERAL AS TPTRIBDESTINO,
                                        TPATVEMP.IDTIPOATIVIDADE AS ATVORIGEM,
                                        TPATVCLI.IDTIPOATIVIDADE AS ATVDESTINO
                                    FROM
                                        DBA.ORCAMENTO ORC
                                    LEFT JOIN
                                        DBA.CLIENTE_FORNECEDOR CLI ON
                                            CLI.IDCLIFOR = ORC.IDCLIFOR
                                    LEFT JOIN
                                        DBA.EMPRESA EMP ON
                                            EMP.IDEMPRESA = ORC.IDEMPRESA
                                    LEFT JOIN
                                        DBA.ATIVIDADE_TIPO_ATIVIDADE TPATVEMP ON
                                            TPATVEMP.FLAGPADRAO = 'T' AND
                                            TPATVEMP.IDATIVIDADE = EMP.IDATIVIDADE
                                    LEFT JOIN
                                        DBA.ATIVIDADE_TIPO_ATIVIDADE TPATVCLI ON
                                            TPATVCLI.FLAGPADRAO = 'T' AND
                                            TPATVCLI.IDATIVIDADE = CLI.IDATIVIDADE
                                    WHERE
                                        ORC.IDEMPRESA = IN_IDEMPRESA AND
                                        ORC.IDORCAMENTO = IN_IDPEDIDO);
        SET LI_IDCENARIOPROD =
                              ( SELECT
                                    CF.IDCENARIOFISCAL
                                FROM
                                    DBA.CENARIO_FISCAL_DADOS_VW CF
                                WHERE
                                    CF.IDTIPOOPERACAO               = 96 AND
                                    CF.IDORIGEMPRODUTO              = 0  AND
                                    CF.FLAGINATIVO                  = 'F' AND
                                    CF.IDPRODUTO                    = IN_IDPRODUTO AND
                                    CF.IDSUBPRODUTO                 = IN_IDSUBPRODUTO AND
                                    CF.UFORIGEM                     = CEN_UFORIGEM AND
                                    CF.UFDESTINO                    = CEN_UFDESTINO AND
                                    CF.TIPOREGIMETRIBFEDERALORIGEM  = CEN_TPTRIBORIGEM AND
                                    CF.TIPOREGIMETRIBFEDERALDESTINO = CEN_TPTRIBDESTINO AND
                                    CF.IDTIPOATIVIDADEORIGEM        = CEN_ATVORIGEM AND
                                    CF.IDTIPOATIVIDADEDESTINO       = CEN_ATVDESTINO );
    END IF;
    IF IN_VALDESCONTOPRO <> 0 THEN
        SET LD_PERDESCONTO = (IN_VALDESCONTOPRO)*100/(IN_QTDPRODUTO*IN_VALUNITBRUTO);
    END IF;
    IF EXISTS (SELECT 1 FROM DBA.ORCAMENTO_PROD ORCAMENTO_PROD WHERE ORCAMENTO_PROD.IDEMPRESA = IN_IDEMPRESA AND ORCAMENTO_PROD.IDORCAMENTO = IN_IDPEDIDO AND
        ORCAMENTO_PROD.IDPRODUTO = IN_IDPRODUTO AND ORCAMENTO_PROD.IDSUBPRODUTO = IN_IDSUBPRODUTO AND ORCAMENTO_PROD.NUMSEQUENCIA = IN_NUMSEQUENCIA) THEN
UPDATE
    DBA.ORCAMENTO_PROD
SET
    IDVENDEDOR               =   IN_IDVENDEDOR,
    IDLOTE                   =   IN_IDLOTE,
    QTDPRODUTO               =   IN_QTDPRODUTO,
    VALUNITBRUTO             =   IN_VALUNITBRUTO,
    VALTOTLIQUIDO            =   IN_VALTOTLIQUIDO,
    VALDESCONTOPRO           =   IN_VALDESCONTOPRO,
    PERDESCONTOPRO           =   LD_PERDESCONTO,
    VALDESCONTOFINANCEIRO    =   IN_VALDESCONTOFINANCEIRO,
    VALACRESCIMOPRO          =   IN_VALACRESCIMOPRO,
    VALACRESCIMOFINANCEIRO   =   IN_VALACRESCIMOFINANCEIRO,
    TIPOENTREGA              =   IN_TIPOENTREGA,
    PERCOMISSAO              =   IN_PERCOMISSAO,
    IDLOCALRETIRADAENTREGA   =   IN_IDLOCALRETIRADAENTREGA,
    IDLOCALRETIRADA          =   IN_IDLOCALRETIRADA,
    IDCENARIOFISCAL          =   LI_IDCENARIOPROD,
    VALFRETE                 =   IN_VALFRETE
WHERE
        IDEMPRESA    = IN_IDEMPRESA      AND
        IDORCAMENTO  = IN_IDPEDIDO       AND
        IDPRODUTO    = IN_IDPRODUTO      AND
        IDSUBPRODUTO = IN_IDSUBPRODUTO   AND
        NUMSEQUENCIA = IN_NUMSEQUENCIA;
    GET DIAGNOSTICS HOUVEALTERACAO = ROW_COUNT;
    IF HOUVEALTERACAO > 0 THEN
            SET STATUSITENSPEDIDO = 2;
    END IF;
    ELSE
        INSERT INTO DBA.ORCAMENTO_PROD(
            IDORCAMENTO,    IDEMPRESA,      IDVENDEDOR,             IDPRODUTO,          IDSUBPRODUTO,           NUMSEQUENCIA,   IDLOTE,         QTDPRODUTO,             VALUNITBRUTO,
            VALTOTLIQUIDO,  VALDESCONTOPRO, VALDESCONTOFINANCEIRO,  VALACRESCIMOPRO,    VALACRESCIMOFINANCEIRO, TIPOENTREGA,    PERCOMISSAO,    IDLOCALRETIRADAENTREGA, IDLOCALRETIRADA,
            IDCENARIOFISCAL, VALFRETE, PERDESCONTOPRO)
        VALUES (
            IN_IDPEDIDO,        IN_IDEMPRESA,       IN_IDVENDEDOR,              IN_IDPRODUTO,           IN_IDSUBPRODUTO,            IN_NUMSEQUENCIA,    LS_IDLOTE,          IN_QTDPRODUTO,              IN_VALUNITBRUTO,
            IN_VALTOTLIQUIDO,   IN_VALDESCONTOPRO,  IN_VALDESCONTOFINANCEIRO,   IN_VALACRESCIMOPRO,     IN_VALACRESCIMOFINANCEIRO,  IN_TIPOENTREGA,     IN_PERCOMISSAO,     IN_IDLOCALRETIRADAENTREGA,  IN_IDLOCALRETIRADA,
            LI_IDCENARIOPROD,   IN_VALFRETE,        LD_PERDESCONTO
        );
    GET DIAGNOSTICS HOUVEALTERACAO = ROW_COUNT;
    IF HOUVEALTERACAO > 0 THEN
            SET STATUSITENSPEDIDO = 1;
    END IF;
        /*Contador de Reserva*/
    UPDATE DBA.CONFIG_CONTADOR SET IDCONTADOR = IDCONTADOR WHERE DESCRCONTADOR = 'CTDESTOQUETMP';
    SET LI_IDCONTADORRESERVA = (SELECT IDCONTADOR FROM DBA.CONFIG_CONTADOR WHERE DESCRCONTADOR = 'CTDESTOQUETMP');
    UPDATE DBA.CONFIG_CONTADOR SET IDCONTADOR = IDCONTADOR + 1 WHERE DESCRCONTADOR = 'CTDESTOQUETMP';
    IF (LC_TIPOPEDIDO = 'P' OR (SELECT FLAGATIVARESERVAORCAMENTO FROM DBA.CONFIG_GERAL WHERE IDCONFIGGERAL = 1) = 'T') THEN
            /*Reserva de estoque*/
            INSERT INTO DBA.ESTOQUE_ANALITICO_TMP(
                IDEMPRESA,
                NUMSEQUENCIA,
                IDPRODUTO,
                IDSUBPRODUTO,
                IDLOTE,
                DTMOVIMENTO,
                IDLOCALESTOQUE,
                IDEMPRESABAIXAEST,
                IDLOCALRETIRADA,
                TIPOBAIXAMESTRE,
                QTDPRODUTO,
                IDOPERACAO,
                IDCONTADORRESERVA,
                NUMNOTA,
                NUMPEDIDO,
                IDCLIENTE,
                ORIGEMRESERVA,
                TIPODOCUMENTO,
                VALFRETE
            ) VALUES (
                IN_IDEMPRESA,
                IN_NUMSEQUENCIA,
                IN_IDPRODUTO,
                IN_IDSUBPRODUTO,
                LS_IDLOTE,
                CURRENT DATE,
                LI_IDLOCALESTOQUE,
                IN_IDEMPRESA,
                IN_IDLOCALRETIRADA,
                LC_TIPOBAIXAMESTRE,
                IN_QTDPRODUTO,
                LI_IDOPERACAO,
                LI_IDCONTADORRESERVA,
                IN_IDPEDIDO,
                IN_IDPEDIDO,
                LI_IDCLIFOR,
                LC_ORIGEMRESERVA,
                LC_TIPODOCUMENTO,
                IN_VALFRETE
            );
END IF;
END IF;
RETURN (VALUES(STATUSITENSPEDIDO));
END