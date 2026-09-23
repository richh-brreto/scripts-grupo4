-- Criação do banco de dados
CREATE DATABASE IF NOT EXISTS boost;
USE boost;

-- 1. Tabela Tipo Professor
CREATE TABLE tipo_professor (
    id_tipo_professor INT AUTO_INCREMENT PRIMARY KEY,
    tipo_professor VARCHAR(45) NOT NULL
);

-- 2. Tabela Professor (Refatorada com Soft Delete)
CREATE TABLE professor (
    id_professor INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(45) NOT NULL,
    email VARCHAR(45) NOT NULL,
    telefone VARCHAR(20) NOT NULL,
    senha VARCHAR(255) NOT NULL,
    tipo_professor_id_tipo_professor INT NOT NULL,
    ativo TINYINT DEFAULT 1, -- 1 para Ativo, 0 para Inativo (Soft Delete)
    CONSTRAINT fk_professor_tipo FOREIGN KEY (tipo_professor_id_tipo_professor)
        REFERENCES tipo_professor(id_tipo_professor)
);

-- 3. Tabela Turma
CREATE TABLE turma (
    id_turma INT AUTO_INCREMENT PRIMARY KEY,
    nome_turma VARCHAR(45) NOT NULL,
    nivel VARCHAR(45),
    limite_alunos INT,
    tipo VARCHAR(45),
    professor_id_professor INT,
    CONSTRAINT fk_turma_professor FOREIGN KEY (professor_id_professor)
        REFERENCES professor(id_professor)
);

-- 4. Tabela Aluno (Refatorada com Soft Delete)
CREATE TABLE aluno (
    id_aluno INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    telefone VARCHAR(20),
    nivel VARCHAR(45),
    ativo TINYINT DEFAULT 1 -- 1 para Ativo, 0 para Inativo (Soft Delete)
);

-- 5. Tabela Horário
CREATE TABLE horario (
    id_horario INT AUTO_INCREMENT PRIMARY KEY,
    dia_semana VARCHAR(45) NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fim TIME NOT NULL
);

-- 6. Tabelas de Disponibilidade (Relacionamentos N:N)
CREATE TABLE disponibilidade_professor (
    professor_id_professor INT NOT NULL,
    horario_id_horario INT NOT NULL,
    is_disponivel BOOLEAN NOT NULL DEFAULT TRUE, -- 🔄 Atualizado: TRUE = Livre/Disponível, FALSE = Ocupado
    PRIMARY KEY (professor_id_professor, horario_id_horario),
    CONSTRAINT fk_disp_prof FOREIGN KEY (professor_id_professor) REFERENCES professor(id_professor),
    CONSTRAINT fk_disp_prof_horario FOREIGN KEY (horario_id_horario) REFERENCES horario(id_horario)
);

CREATE TABLE disponibilidade_aluno (
    horario_id_horario INT NOT NULL,
    aluno_id_aluno INT NOT NULL,
    is_disponivel BOOLEAN NOT NULL DEFAULT TRUE, -- 🔄 Atualizado: TRUE = Livre/Disponível, FALSE = Ocupado
    PRIMARY KEY (horario_id_horario, aluno_id_aluno),
    CONSTRAINT fk_disp_aluno_horario FOREIGN KEY (horario_id_horario) REFERENCES horario(id_horario),
    CONSTRAINT fk_disp_aluno FOREIGN KEY (aluno_id_aluno) REFERENCES aluno(id_aluno)
);

CREATE TABLE disponibilidade_turma (
    turma_id_turma INT NOT NULL,
    horario_id_horario INT NOT NULL,
    PRIMARY KEY (turma_id_turma, horario_id_horario),
    CONSTRAINT fk_disp_turma FOREIGN KEY (turma_id_turma) REFERENCES turma(id_turma),
    CONSTRAINT fk_disp_turma_horario FOREIGN KEY (horario_id_horario) REFERENCES horario(id_horario)
);

-- 7. Tabela Contrato (Campos opcionais com NULL para Individual/Grupo)
CREATE TABLE contrato (
    id_contrato INT AUTO_INCREMENT PRIMARY KEY,
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    tipo VARCHAR(45),
    professor_id_professor INT NULL,
    aluno_id_aluno INT NULL,
    turma_id_turma INT NULL,
    CONSTRAINT fk_contrato_professor FOREIGN KEY (professor_id_professor) REFERENCES professor(id_professor),
    CONSTRAINT fk_contrato_aluno FOREIGN KEY (aluno_id_aluno) REFERENCES aluno(id_aluno),
    CONSTRAINT fk_contrato_turma FOREIGN KEY (turma_id_turma) REFERENCES turma(id_turma)
);

-- 8. Tabela Auxiliar de Horários do Contrato Individual
CREATE TABLE ids_horario_contrato (
    contrato_id_contrato INT NOT NULL,
    horario_id_horario INT NOT NULL,
    PRIMARY KEY (contrato_id_contrato, horario_id_horario),
    CONSTRAINT fk_horario_contrato_id FOREIGN KEY (contrato_id_contrato) REFERENCES contrato(id_contrato),
    CONSTRAINT fk_horario_contrato_horario FOREIGN KEY (horario_id_horario) REFERENCES horario(id_horario)
);

-- 9. Tabela Aula
CREATE TABLE aula (
    id_aula INT AUTO_INCREMENT PRIMARY KEY,
    data DATE NOT NULL,
    presenca TINYINT DEFAULT 0,
    status VARCHAR(45),
    hora_inicio TIME,
    hora_fim TIME,
    contrato_id_contrato INT NOT NULL,
    CONSTRAINT fk_aula_contrato FOREIGN KEY (contrato_id_contrato) REFERENCES contrato(id_contrato) ON DELETE CASCADE
);

-- 10. Tabela Logs
CREATE TABLE logs (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    acao VARCHAR(50),
    descricao TEXT,
    data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    aula_id_aula INT,
    CONSTRAINT fk_logs_aula FOREIGN KEY (aula_id_aula) REFERENCES aula(id_aula) ON DELETE CASCADE
);

	-- Segunda-feira
	INSERT INTO horario (dia_semana, hora_inicio, hora_fim) VALUES
	('Segunda-feira', '06:00:00', '07:00:00'), ('Segunda-feira', '07:00:00', '08:00:00'),
	('Segunda-feira', '08:00:00', '09:00:00'), ('Segunda-feira', '09:00:00', '10:00:00'),
	('Segunda-feira', '10:00:00', '11:00:00'), ('Segunda-feira', '11:00:00', '12:00:00'),
	('Segunda-feira', '12:00:00', '13:00:00'), ('Segunda-feira', '13:00:00', '14:00:00'),
	('Segunda-feira', '14:00:00', '15:00:00'), ('Segunda-feira', '15:00:00', '16:00:00'),
	('Segunda-feira', '16:00:00', '17:00:00'), ('Segunda-feira', '17:00:00', '18:00:00'),
	('Segunda-feira', '18:00:00', '19:00:00'), ('Segunda-feira', '19:00:00', '20:00:00'),
	('Segunda-feira', '20:00:00', '21:00:00'), ('Segunda-feira', '21:00:00', '22:00:00'),
	('Segunda-feira', '22:00:00', '23:00:00');

	-- Terça-feira
	INSERT INTO horario (dia_semana, hora_inicio, hora_fim) VALUES
	('Terça-feira', '06:00:00', '07:00:00'), ('Terça-feira', '07:00:00', '08:00:00'),
	('Terça-feira', '08:00:00', '09:00:00'), ('Terça-feira', '09:00:00', '10:00:00'),
	('Terça-feira', '10:00:00', '11:00:00'), ('Terça-feira', '11:00:00', '12:00:00'),
	('Terça-feira', '12:00:00', '13:00:00'), ('Terça-feira', '13:00:00', '14:00:00'),
	('Terça-feira', '14:00:00', '15:00:00'), ('Terça-feira', '15:00:00', '16:00:00'),
	('Terça-feira', '16:00:00', '17:00:00'), ('Terça-feira', '17:00:00', '18:00:00'),
	('Terça-feira', '18:00:00', '19:00:00'), ('Terça-feira', '19:00:00', '20:00:00'),
	('Terça-feira', '20:00:00', '21:00:00'), ('Terça-feira', '21:00:00', '22:00:00'),
	('Terça-feira', '22:00:00', '23:00:00');

	-- Quarta-feira
	INSERT INTO horario (dia_semana, hora_inicio, hora_fim) VALUES
	('Quarta-feira', '06:00:00', '07:00:00'), ('Quarta-feira', '07:00:00', '08:00:00'),
	('Quarta-feira', '08:00:00', '09:00:00'), ('Quarta-feira', '09:00:00', '10:00:00'),
	('Quarta-feira', '10:00:00', '11:00:00'), ('Quarta-feira', '11:00:00', '12:00:00'),
	('Quarta-feira', '12:00:00', '13:00:00'), ('Quarta-feira', '13:00:00', '14:00:00'),
	('Quarta-feira', '14:00:00', '15:00:00'), ('Quarta-feira', '15:00:00', '16:00:00'),
	('Quarta-feira', '16:00:00', '17:00:00'), ('Quarta-feira', '17:00:00', '18:00:00'),
	('Quarta-feira', '18:00:00', '19:00:00'), ('Quarta-feira', '19:00:00', '20:00:00'),
	('Quarta-feira', '20:00:00', '21:00:00'), ('Quarta-feira', '21:00:00', '22:00:00'),
	('Quarta-feira', '22:00:00', '23:00:00');

	-- Quinta-feira
	INSERT INTO horario (dia_semana, hora_inicio, hora_fim) VALUES
	('Quinta-feira', '06:00:00', '07:00:00'), ('Quinta-feira', '07:00:00', '08:00:00'),
	('Quinta-feira', '08:00:00', '09:00:00'), ('Quinta-feira', '09:00:00', '10:00:00'),
	('Quinta-feira', '10:00:00', '11:00:00'), ('Quinta-feira', '11:00:00', '12:00:00'),
	('Quinta-feira', '12:00:00', '13:00:00'), ('Quinta-feira', '13:00:00', '14:00:00'),
	('Quinta-feira', '14:00:00', '15:00:00'), ('Quinta-feira', '15:00:00', '16:00:00'),
	('Quinta-feira', '16:00:00', '17:00:00'), ('Quinta-feira', '17:00:00', '18:00:00'),
	('Quinta-feira', '18:00:00', '19:00:00'), ('Quinta-feira', '19:00:00', '20:00:00'),
	('Quinta-feira', '20:00:00', '21:00:00'), ('Quinta-feira', '21:00:00', '22:00:00'),
	('Quinta-feira', '22:00:00', '23:00:00');

	-- Sexta-feira
	INSERT INTO horario (dia_semana, hora_inicio, hora_fim) VALUES
	('Sexta-feira', '06:00:00', '07:00:00'), ('Sexta-feira', '07:00:00', '08:00:00'),
	('Sexta-feira', '08:00:00', '09:00:00'), ('Sexta-feira', '09:00:00', '10:00:00'),
	('Sexta-feira', '10:00:00', '11:00:00'), ('Sexta-feira', '11:00:00', '12:00:00'),
	('Sexta-feira', '12:00:00', '13:00:00'), ('Sexta-feira', '13:00:00', '14:00:00'),
	('Sexta-feira', '14:00:00', '15:00:00'), ('Sexta-feira', '15:00:00', '16:00:00'),
	('Sexta-feira', '16:00:00', '17:00:00'), ('Sexta-feira', '17:00:00', '18:00:00'),
	('Sexta-feira', '18:00:00', '19:00:00'), ('Sexta-feira', '19:00:00', '20:00:00'),
	('Sexta-feira', '20:00:00', '21:00:00'), ('Sexta-feira', '21:00:00', '22:00:00'),
	('Sexta-feira', '22:00:00', '23:00:00');

	-- Sábado
	INSERT INTO horario (dia_semana, hora_inicio, hora_fim) VALUES
	('Sábado', '06:00:00', '07:00:00'), ('Sábado', '07:00:00', '08:00:00'),
	('Sábado', '08:00:00', '09:00:00'), ('Sábado', '09:00:00', '10:00:00'),
	('Sábado', '10:00:00', '11:00:00'), ('Sábado', '11:00:00', '12:00:00'),
	('Sábado', '12:00:00', '13:00:00'), ('Sábado', '13:00:00', '14:00:00'),
	('Sábado', '14:00:00', '15:00:00'), ('Sábado', '15:00:00', '16:00:00'),
	('Sábado', '16:00:00', '17:00:00'), ('Sábado', '17:00:00', '18:00:00'),
	('Sábado', '18:00:00', '19:00:00'), ('Sábado', '19:00:00', '20:00:00'),
	('Sábado', '20:00:00', '21:00:00'), ('Sábado', '21:00:00', '22:00:00'),
	('Sábado', '22:00:00', '23:00:00');

	-- Domingo
	INSERT INTO horario (dia_semana, hora_inicio, hora_fim) VALUES
	('Domingo', '06:00:00', '07:00:00'), ('Domingo', '07:00:00', '08:00:00'),
	('Domingo', '08:00:00', '09:00:00'), ('Domingo', '09:00:00', '10:00:00'),
	('Domingo', '10:00:00', '11:00:00'), ('Domingo', '11:00:00', '12:00:00'),
	('Domingo', '12:00:00', '13:00:00'), ('Domingo', '13:00:00', '14:00:00'),
	('Domingo', '14:00:00', '15:00:00'), ('Domingo', '15:00:00', '16:00:00'),
	('Domingo', '16:00:00', '17:00:00'), ('Domingo', '17:00:00', '18:00:00'),
	('Domingo', '18:00:00', '19:00:00'), ('Domingo', '19:00:00', '20:00:00'),
	('Domingo', '20:00:00', '21:00:00'), ('Domingo', '21:00:00', '22:00:00'),
	('Domingo', '22:00:00', '23:00:00');

-- ============================================================================
-- 1. CADASTROS BÁSICOS
-- ============================================================================

-- Inserindo o tipo do professor
INSERT INTO tipo_professor (tipo_professor) VALUES ('COORDENADOR'), ('Professor'); -- Gerará o id_tipo_professor = 1

-- Inserindo o Professor
INSERT INTO professor (nome, email, telefone, senha, tipo_professor_id_tipo_professor, ativo)
VALUES ('Administrador Sistema', 'admin@sptech.school', 1199999888, '$2a$12$F03Vd6gjrLJRC8jzliUfA.oA4i248BIfEEejMxwQpZQZJiSC1/KAC', 1, 1); -- Gerará o id_professor = 1

-- Inserindo a Turma (Vinculada ao Professor 1)
INSERT INTO turma (nome_turma, nivel, limite_alunos, tipo, professor_id_professor)
VALUES ('ADS-2B', 'Intermediário', 30, 'Grupo', 1); -- Gerará o id_turma = 1

-- Inserindo o Aluno
INSERT INTO aluno (nome, email, telefone, nivel, ativo)
VALUES ('Guilherme Silva2', 'guilherme.silva@sptech.school', '11977776666', 'Intermediário', 1); -- Gerará o id_aluno = 1


-- ============================================================================
-- 2. VÍNCULO DE DISPONIBILIDADES (3 HORÁRIOS PARA CADA)
-- Confluência no ID 14: Segunda-feira das 19h às 20h
-- ============================================================================

-- Disponibilidade do Professor (ID 1)
-- ID 14: Segunda-feira (19h - 20h) -> PONTO DE ENCONTRO
-- ID 15: Segunda-feira (20h - 21h)
-- ID 16: Segunda-feira (21h - 22h)
INSERT INTO disponibilidade_professor (professor_id_professor, horario_id_horario) VALUES
(1, 14),
(1, 15),
(1, 16);

-- Disponibilidade da Turma (ID 1)
-- ID 14: Segunda-feira (19h - 20h) -> PONTO DE ENCONTRO
-- ID 18: Terça-feira (06h - 07h)
-- ID 19: Terça-feira (07h - 08h)
INSERT INTO disponibilidade_turma (turma_id_turma, horario_id_horario) VALUES
(1, 14),
(1, 18),
(1, 19);

-- Disponibilidade do Aluno (ID 1)
-- ID 14: Segunda-feira (19h - 20h) -> PONTO DE ENCONTRO COM PROFESSOR E TURMA
-- ID 32: Terça-feira (20h - 21h)
-- ID 33: Terça-feira (21h - 22h)
INSERT INTO disponibilidade_aluno (horario_id_horario, aluno_id_aluno) VALUES
(14, 1),
(18, 1),
(19, 1);

SELECT
    a.nome AS Aluno,
    p.nome AS Professor,
    t.nome_turma AS Turma,
    h.dia_semana AS Dia,
    h.hora_inicio AS Inicio,
    h.hora_fim AS Fim
FROM disponibilidade_aluno da
JOIN disponibilidade_professor dp ON da.horario_id_horario = dp.horario_id_horario
JOIN disponibilidade_turma dt ON da.horario_id_horario = dt.horario_id_horario
JOIN aluno a ON da.aluno_id_aluno = a.id_aluno
JOIN professor p ON dp.professor_id_professor = p.id_professor
JOIN turma t ON dt.turma_id_turma = t.id_turma
JOIN horario h ON da.horario_id_horario = h.id_horario;
---------------------------------------------------------------------------------------

select * from contrato;
select * from horario;
select * from professor;
select * from disponibilidade_professor;
select * from disponibilidade_aluno;
select * from turma;
select * from aluno;
select * from tipo_professor;

select * from ids_horario_contrato;
use boost;
