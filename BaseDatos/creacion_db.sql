-- ============================
-- BASE DE DATOS: Aplicación Educativa de Energías Renovables
-- Versión: 2.0 Mejorada
-- ============================

-- ============================
-- TABLA: Usuario
-- ============================
CREATE TABLE Usuario (
    id_usuario VARCHAR(50) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100),
    email VARCHAR(120) UNIQUE NOT NULL,
    contrasena_hash VARCHAR(255) NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT GETDATE(),
    ultimo_acceso DATETIME,
    activo BIT NOT NULL DEFAULT 1,
    permisos VARCHAR(50) CHECK (permisos IN ('estudiante', 'docente', 'admin')),
    avatar VARCHAR(255),
    idioma_preferido VARCHAR(10) DEFAULT 'es'
);

-- ============================
-- TABLA: Sesion
-- ============================
CREATE TABLE Sesion (
    id_sesion INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario VARCHAR(50) NOT NULL,
    fecha_conexion DATETIME NOT NULL DEFAULT GETDATE(),
    fecha_fin DATETIME,
    ubicacion_ip VARCHAR(45),
    dispositivo VARCHAR(100),
    version_app VARCHAR(20),
    CONSTRAINT FK_Sesion_Usuario FOREIGN KEY (id_usuario)
        REFERENCES Usuario(id_usuario) ON DELETE CASCADE
);

-- ============================
-- TABLA: Recursos Multimedia
-- ============================
CREATE TABLE RecursosMultimedia (
    id_recurso INT IDENTITY(1,1) PRIMARY KEY,
    tipo VARCHAR(50) NOT NULL CHECK (tipo IN ('video', 'imagen', 'audio', 'animacion', 'infografia')),
    url VARCHAR(2048) NOT NULL,
    duracion TIME,
    calidad VARCHAR(50),
    tamano_mb DECIMAL(10,2),
    fecha_actualizacion DATETIME NOT NULL DEFAULT GETDATE(),
    disponible_offline BIT DEFAULT 0
);

-- ============================
-- TABLA: Categoria
-- ============================
CREATE TABLE Categoria (
    id_categoria INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    tipo VARCHAR(50) CHECK (tipo IN ('tipo_energia', 'nivel_dificultad', 'tema')),
    descripcion VARCHAR(MAX),
    icono VARCHAR(255)
);

-- ============================
-- TABLA: Modulo
-- ============================
CREATE TABLE Modulo (
    id_modulo INT IDENTITY(1,1) PRIMARY KEY,
    titulo VARCHAR(255) NOT NULL,
    descripcion VARCHAR(MAX),
    tipo_energia VARCHAR(50) CHECK (tipo_energia IN ('solar', 'eolica', 'hidraulica', 'biomasa', 'geotermica', 'otro')),
    nivel_dificultad VARCHAR(50) CHECK (nivel_dificultad IN ('basico', 'intermedio', 'avanzado')),
    orden_secuencial INT,
    imagen_portada VARCHAR(2048),
    activo BIT NOT NULL DEFAULT 1,
    metodologia VARCHAR(MAX),
    actividades_curricular VARCHAR(MAX),
    diploma VARCHAR(MAX),
    duracion_estimada INT, -- en minutos
    prerequisitos VARCHAR(255), -- IDs de módulos previos separados por coma
    puntos_totales INT DEFAULT 0
);

-- ============================
-- TABLA: Modulo_Categoria (Relación M:N)
-- ============================
CREATE TABLE Modulo_Categoria (
    id_modulo INT NOT NULL,
    id_categoria INT NOT NULL,
    PRIMARY KEY (id_modulo, id_categoria),
    CONSTRAINT FK_MC_Modulo FOREIGN KEY (id_modulo)
        REFERENCES Modulo(id_modulo) ON DELETE CASCADE,
    CONSTRAINT FK_MC_Categoria FOREIGN KEY (id_categoria)
        REFERENCES Categoria(id_categoria) ON DELETE CASCADE
);

-- ============================
-- TABLA: Leccion
-- ============================
CREATE TABLE Leccion (
    id_leccion INT IDENTITY(1,1) PRIMARY KEY,
    id_modulo INT NOT NULL,
    titulo VARCHAR(255) NOT NULL,
    contenido VARCHAR(MAX),
    orden_leccion INT NOT NULL,
    puntos_recompensa INT DEFAULT 0,
    duracion TIME,
    objetivos_aprendizaje VARCHAR(MAX),
    palabras_clave VARCHAR(500),
    CONSTRAINT FK_Leccion_Modulo FOREIGN KEY (id_modulo)
        REFERENCES Modulo(id_modulo) ON DELETE CASCADE
);

-- ============================
-- TABLA: Leccion_Recursos (Relación M:N - Una lección puede tener varios recursos)
-- ============================
CREATE TABLE Leccion_Recursos (
    id_leccion INT NOT NULL,
    id_recurso INT NOT NULL,
    orden_visualizacion INT,
    PRIMARY KEY (id_leccion, id_recurso),
    CONSTRAINT FK_LR_Leccion FOREIGN KEY (id_leccion)
        REFERENCES Leccion(id_leccion) ON DELETE CASCADE,
    CONSTRAINT FK_LR_Recurso FOREIGN KEY (id_recurso)
        REFERENCES RecursosMultimedia(id_recurso) ON DELETE CASCADE
);

-- ============================
-- TABLA: Preguntas
-- ============================
CREATE TABLE Preguntas (
    id_pregunta INT IDENTITY(1,1) PRIMARY KEY,
    tipo VARCHAR(50) NOT NULL CHECK (tipo IN ('opcion_multiple', 'verdadero_falso', 'relacionar', 'completar', 'abierta')),
    enunciado VARCHAR(MAX) NOT NULL,
    opciones VARCHAR(MAX), -- JSON con las opciones
    respuesta_correcta VARCHAR(MAX),
    puntos INT DEFAULT 1,
    dificultad VARCHAR(50) CHECK (dificultad IN ('facil', 'media', 'dificil')),
    retroalimentacion_correcta VARCHAR(MAX),
    retroalimentacion_incorrecta VARCHAR(MAX),
    explicacion VARCHAR(MAX)
);

-- ============================
-- TABLA: Actividad
-- ============================
CREATE TABLE Actividad (
    id_actividad INT IDENTITY(1,1) PRIMARY KEY,
    id_leccion INT NOT NULL,
    titulo VARCHAR(255) NOT NULL,
    descripcion VARCHAR(MAX),
    tipo_actividad VARCHAR(50) CHECK (tipo_actividad IN ('quiz', 'minijuego', 'ejercicio_practico', 'simulacion')),
    puntos_maximos INT DEFAULT 0,
    tiempo_estimado TIME,
    obligatoria BIT DEFAULT 1,
    CONSTRAINT FK_Actividad_Leccion FOREIGN KEY (id_leccion)
        REFERENCES Leccion(id_leccion) ON DELETE CASCADE
);

-- ============================
-- TABLA: Evaluacion
-- ============================
CREATE TABLE Evaluacion (
    id_evaluacion INT IDENTITY(1,1) PRIMARY KEY,
    id_actividad INT NOT NULL,
    tipo_evaluacion VARCHAR(50) NOT NULL CHECK (tipo_evaluacion IN ('diagnostica', 'formativa', 'sumativa')),
    tiempo_limite INT CHECK (tiempo_limite >= 0), -- en minutos
    puntos_maximos INT CHECK (puntos_maximos > 0),
    puntuacion_minima INT CHECK (puntuacion_minima >= 0),
    preguntas_aleatorias BIT DEFAULT 0,
    intentos_permitidos INT DEFAULT 3,
    mostrar_resultados_inmediatos BIT DEFAULT 1,
    CONSTRAINT FK_Evaluacion_Actividad FOREIGN KEY (id_actividad)
        REFERENCES Actividad(id_actividad) ON DELETE CASCADE
);

-- ============================
-- TABLA: Evaluacion_Preguntas (Relación M:N)
-- ============================
CREATE TABLE Evaluacion_Preguntas (
    id_evaluacion INT NOT NULL,
    id_pregunta INT NOT NULL,
    orden_pregunta INT,
    PRIMARY KEY (id_evaluacion, id_pregunta),
    CONSTRAINT FK_EP_Evaluacion FOREIGN KEY (id_evaluacion)
        REFERENCES Evaluacion(id_evaluacion) ON DELETE CASCADE,
    CONSTRAINT FK_EP_Pregunta FOREIGN KEY (id_pregunta)
        REFERENCES Preguntas(id_pregunta) ON DELETE CASCADE
);

-- ============================
-- TABLA: Leccion_Preguntas (Relación M:N)
-- ============================
CREATE TABLE Leccion_Preguntas (
    id_leccion INT NOT NULL,
    id_pregunta INT NOT NULL,
    orden_pregunta INT,
    PRIMARY KEY (id_leccion, id_pregunta),
    CONSTRAINT FK_LP_Leccion FOREIGN KEY (id_leccion)
        REFERENCES Leccion(id_leccion) ON DELETE CASCADE,
    CONSTRAINT FK_LP_Preguntas FOREIGN KEY (id_pregunta)
        REFERENCES Preguntas(id_pregunta) ON DELETE CASCADE
);

-- ============================
-- ESPECIALIZACIÓN DE ACTIVIDAD
-- ============================
CREATE TABLE Quiz (
    id_actividad INT PRIMARY KEY,
    preguntas VARCHAR(MAX), -- IDs de preguntas en JSON
    adaptativo BIT DEFAULT 0,
    banco_preguntas BIT DEFAULT 0,
    CONSTRAINT FK_Quiz_Actividad FOREIGN KEY (id_actividad)
        REFERENCES Actividad(id_actividad) ON DELETE CASCADE
);

CREATE TABLE Minijuego (
    id_actividad INT PRIMARY KEY,
    mecanica VARCHAR(MAX),
    niveles INT CHECK (niveles >= 1),
    instrucciones VARCHAR(MAX),
    recursos_juego VARCHAR(MAX), -- JSON con assets necesarios
    CONSTRAINT FK_Minijuego_Actividad FOREIGN KEY (id_actividad)
        REFERENCES Actividad(id_actividad) ON DELETE CASCADE
);

-- ============================
-- ESPECIALIZACIÓN DE USUARIO
-- ============================
CREATE TABLE Estudiante (
    id_usuario VARCHAR(50) PRIMARY KEY,
    grado VARCHAR(50),
    institucion VARCHAR(200),
    puntos_totales INT DEFAULT 0,
    nivel INT DEFAULT 1,
    racha INT DEFAULT 0,
    fecha_ultima_actividad DATE,
    experiencia INT DEFAULT 0,
    CONSTRAINT FK_Estudiante_Usuario FOREIGN KEY (id_usuario)
        REFERENCES Usuario(id_usuario) ON DELETE CASCADE
);

CREATE TABLE Docente (
    id_usuario VARCHAR(50) PRIMARY KEY,
    especialidad VARCHAR(100),
    experiencia INT CHECK (experiencia >= 0),
    anio INT CHECK (anio >= 0),
    institucion VARCHAR(200),
    cedula_profesional VARCHAR(50),
    CONSTRAINT FK_Docente_Usuario FOREIGN KEY (id_usuario)
        REFERENCES Usuario(id_usuario) ON DELETE CASCADE
);

-- ============================
-- TABLA: Progreso del Estudiante
-- ============================
CREATE TABLE Progreso_Estudiante (
    id_progreso INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario VARCHAR(50) NOT NULL,
    id_leccion INT NOT NULL,
    estado VARCHAR(20) CHECK (estado IN ('no_iniciado', 'en_curso', 'completado')) DEFAULT 'no_iniciado',
    fecha_inicio DATETIME,
    fecha_completado DATETIME,
    puntos_obtenidos INT DEFAULT 0,
    porcentaje_avance DECIMAL(5,2) DEFAULT 0.00,
    tiempo_invertido INT DEFAULT 0, -- en minutos
    CONSTRAINT FK_PE_Estudiante FOREIGN KEY (id_usuario)
        REFERENCES Estudiante(id_usuario) ON DELETE CASCADE,
    CONSTRAINT FK_PE_Leccion FOREIGN KEY (id_leccion)
        REFERENCES Leccion(id_leccion) ON DELETE CASCADE,
    CONSTRAINT UQ_Progreso UNIQUE (id_usuario, id_leccion)
);

-- ============================
-- TABLA: Intento de Evaluación (Historial)
-- ============================
CREATE TABLE Intento_Evaluacion (
    id_intento INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario VARCHAR(50) NOT NULL,
    id_evaluacion INT NOT NULL,
    fecha_intento DATETIME DEFAULT GETDATE(),
    puntuacion_obtenida INT,
    puntuacion_maxima INT,
    tiempo_empleado INT, -- en segundos
    aprobado BIT,
    respuestas VARCHAR(MAX), -- JSON con respuestas del estudiante
    numero_intento INT DEFAULT 1,
    CONSTRAINT FK_IE_Estudiante FOREIGN KEY (id_usuario)
        REFERENCES Estudiante(id_usuario) ON DELETE CASCADE,
    CONSTRAINT FK_IE_Evaluacion FOREIGN KEY (id_evaluacion)
        REFERENCES Evaluacion(id_evaluacion) ON DELETE CASCADE
);

-- ============================
-- TABLA: Retroalimentacion Detallada
-- ============================
CREATE TABLE Retroalimentacion (
    id_retroalimentacion INT IDENTITY(1,1) PRIMARY KEY,
    id_intento INT NOT NULL,
    titulo VARCHAR(255),
    contenido VARCHAR(MAX),
    recursos_multimedia VARCHAR(MAX), -- JSON con URLs de recursos adicionales
    nivel_superacion VARCHAR(50) CHECK (nivel_superacion IN ('excelente', 'bueno', 'regular', 'necesita_mejorar')),
    recomendaciones VARCHAR(MAX),
    areas_reforzar VARCHAR(MAX), -- Temas que debe repasar
    fecha_generacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Retro_Intento FOREIGN KEY (id_intento)
        REFERENCES Intento_Evaluacion(id_intento) ON DELETE CASCADE
);

-- ============================
-- TABLA: Contenido Descargado (Modo Offline)
-- ============================
CREATE TABLE Contenido_Descargado (
    id_descarga INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario VARCHAR(50) NOT NULL,
    id_modulo INT NOT NULL,
    fecha_descarga DATETIME DEFAULT GETDATE(),
    fecha_expiracion DATETIME,
    tamano_total_mb DECIMAL(10,2),
    estado VARCHAR(50) CHECK (estado IN ('descargando', 'disponible', 'expirado')) DEFAULT 'disponible',
    CONSTRAINT FK_CD_Usuario FOREIGN KEY (id_usuario)
        REFERENCES Usuario(id_usuario) ON DELETE CASCADE,
    CONSTRAINT FK_CD_Modulo FOREIGN KEY (id_modulo)
        REFERENCES Modulo(id_modulo) ON DELETE CASCADE,
    CONSTRAINT UQ_Descarga UNIQUE (id_usuario, id_modulo)
);

-- ============================
-- TABLAS DE GAMIFICACIÓN
-- ============================
CREATE TABLE Logro (
    id_logro INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(MAX),
    icono VARCHAR(2048),
    requisito_tipo VARCHAR(50) CHECK (requisito_tipo IN ('racha', 'puntos', 'modulos_completados', 'actividades', 'tiempo')),
    requisito_valor INT, -- ejemplo: 5 días seguidos, 1000 puntos
    puntos_otorgados INT DEFAULT 0,
    categoria VARCHAR(50), -- 'bronce', 'plata', 'oro', 'platino'
    activo BIT DEFAULT 1
);

CREATE TABLE Estudiante_Logro (
    id_usuario VARCHAR(50),
    id_logro INT,
    fecha_obtenido DATETIME DEFAULT GETDATE(),
    notificado BIT DEFAULT 0,
    PRIMARY KEY (id_usuario, id_logro),
    CONSTRAINT FK_EL_Estudiante FOREIGN KEY (id_usuario)
        REFERENCES Estudiante(id_usuario) ON DELETE CASCADE,
    CONSTRAINT FK_EL_Logro FOREIGN KEY (id_logro)
        REFERENCES Logro(id_logro) ON DELETE CASCADE
);

-- ============================
-- TABLA: Ranking/Leaderboard
-- ============================
CREATE TABLE Ranking (
    id_ranking INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario VARCHAR(50) NOT NULL,
    posicion INT,
    puntos INT DEFAULT 0,
    periodo VARCHAR(50) CHECK (periodo IN ('semanal', 'mensual', 'anual', 'global')),
    fecha_actualizacion DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Ranking_Estudiante FOREIGN KEY (id_usuario)
        REFERENCES Estudiante(id_usuario) ON DELETE CASCADE
);

-- ============================
-- TABLA: Notificaciones
-- ============================
CREATE TABLE Notificacion (
    id_notificacion INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario VARCHAR(50) NOT NULL,
    titulo VARCHAR(255) NOT NULL,
    mensaje VARCHAR(MAX),
    tipo VARCHAR(50) CHECK (tipo IN ('logro', 'recordatorio', 'actualizacion', 'social', 'sistema')),
    leida BIT DEFAULT 0,
    fecha_creacion DATETIME DEFAULT GETDATE(),
    fecha_leida DATETIME,
    CONSTRAINT FK_Notif_Usuario FOREIGN KEY (id_usuario)
        REFERENCES Usuario(id_usuario) ON DELETE CASCADE
);

-- ============================
-- ÍNDICES PARA OPTIMIZACIÓN
-- ============================
CREATE INDEX IDX_Usuario_Email ON Usuario(email);
CREATE INDEX IDX_Sesion_Usuario_Fecha ON Sesion(id_usuario, fecha_conexion);
CREATE INDEX IDX_Leccion_Modulo ON Leccion(id_modulo);
CREATE INDEX IDX_Actividad_Leccion ON Actividad(id_leccion);
CREATE INDEX IDX_Progreso_Usuario ON Progreso_Estudiante(id_usuario);
CREATE INDEX IDX_Progreso_Estado ON Progreso_Estudiante(estado);
CREATE INDEX IDX_Intento_Usuario ON Intento_Evaluacion(id_usuario);
CREATE INDEX IDX_Estudiante_Puntos ON Estudiante(puntos_totales DESC);
CREATE INDEX IDX_Ranking_Periodo ON Ranking(periodo, posicion);
CREATE INDEX IDX_Notificacion_Usuario_Leida ON Notificacion(id_usuario, leida);

-- ============================
-- FIN DEL SCRIPT
-- ============================