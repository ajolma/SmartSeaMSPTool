--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.6
-- Dumped by pg_dump version 9.5.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: data; Type: SCHEMA; Schema: -; Owner: ajolma
--

CREATE SCHEMA data;


ALTER SCHEMA data OWNER TO ajolma;

--
-- Name: tool; Type: SCHEMA; Schema: -; Owner: ajolma
--

CREATE SCHEMA tool;


ALTER SCHEMA tool OWNER TO ajolma;

--
-- Name: SCHEMA tool; Type: COMMENT; Schema: -; Owner: ajolma
--

COMMENT ON SCHEMA tool IS 'Core tables for the tool';


SET search_path = data, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: data_models; Type: TABLE; Schema: data; Owner: ajolma
--

CREATE TABLE data_models (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE data_models OWNER TO ajolma;

--
-- Name: data models_id_seq; Type: SEQUENCE; Schema: data; Owner: ajolma
--

CREATE SEQUENCE "data models_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "data models_id_seq" OWNER TO ajolma;

--
-- Name: data models_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: ajolma
--

ALTER SEQUENCE "data models_id_seq" OWNED BY data_models.id;


--
-- Name: datasets; Type: TABLE; Schema: data; Owner: ajolma
--

CREATE TABLE datasets (
    id integer NOT NULL,
    name text NOT NULL,
    custodian integer,
    contact text,
    descr text,
    data_model integer,
    is_a_part_of integer,
    is_derived_from integer,
    license integer,
    attribution text,
    disclaimer text,
    path text,
    unit integer,
    style integer
);


ALTER TABLE datasets OWNER TO ajolma;

--
-- Name: COLUMN datasets.style; Type: COMMENT; Schema: data; Owner: ajolma
--

COMMENT ON COLUMN datasets.style IS 'required if path is not null, ie real data';


--
-- Name: datasets_id_seq; Type: SEQUENCE; Schema: data; Owner: ajolma
--

CREATE SEQUENCE datasets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE datasets_id_seq OWNER TO ajolma;

--
-- Name: datasets_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: ajolma
--

ALTER SEQUENCE datasets_id_seq OWNED BY datasets.id;


--
-- Name: layers; Type: TABLE; Schema: data; Owner: ajolma
--

CREATE TABLE layers (
    id integer NOT NULL,
    site text,
    folder text,
    service text,
    kind text,
    layer text,
    lid integer,
    parent integer
);


ALTER TABLE layers OWNER TO ajolma;

--
-- Name: TABLE layers; Type: COMMENT; Schema: data; Owner: ajolma
--

COMMENT ON TABLE layers IS 'remote layers';


--
-- Name: licenses; Type: TABLE; Schema: data; Owner: ajolma
--

CREATE TABLE licenses (
    id integer NOT NULL,
    name text NOT NULL,
    url text
);


ALTER TABLE licenses OWNER TO ajolma;

--
-- Name: licenses_id_seq; Type: SEQUENCE; Schema: data; Owner: ajolma
--

CREATE SEQUENCE licenses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE licenses_id_seq OWNER TO ajolma;

--
-- Name: licenses_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: ajolma
--

ALTER SEQUENCE licenses_id_seq OWNED BY licenses.id;


--
-- Name: organizations; Type: TABLE; Schema: data; Owner: ajolma
--

CREATE TABLE organizations (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE organizations OWNER TO ajolma;

--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: data; Owner: ajolma
--

CREATE SEQUENCE organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE organizations_id_seq OWNER TO ajolma;

--
-- Name: organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: ajolma
--

ALTER SEQUENCE organizations_id_seq OWNED BY organizations.id;


--
-- Name: remote_id_seq; Type: SEQUENCE; Schema: data; Owner: ajolma
--

CREATE SEQUENCE remote_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE remote_id_seq OWNER TO ajolma;

--
-- Name: remote_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: ajolma
--

ALTER SEQUENCE remote_id_seq OWNED BY layers.id;


--
-- Name: units; Type: TABLE; Schema: data; Owner: ajolma
--

CREATE TABLE units (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE units OWNER TO ajolma;

--
-- Name: units_id_seq; Type: SEQUENCE; Schema: data; Owner: ajolma
--

CREATE SEQUENCE units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE units_id_seq OWNER TO ajolma;

--
-- Name: units_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: ajolma
--

ALTER SEQUENCE units_id_seq OWNED BY units.id;


SET search_path = tool, pg_catalog;

--
-- Name: activities; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE activities (
    id integer NOT NULL,
    name text NOT NULL,
    ordr integer DEFAULT 1 NOT NULL
);


ALTER TABLE activities OWNER TO ajolma;

--
-- Name: activities_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE activities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE activities_id_seq OWNER TO ajolma;

--
-- Name: activities_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE activities_id_seq OWNED BY activities.id;


--
-- Name: activity2pressure; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE activity2pressure (
    id integer NOT NULL,
    activity integer NOT NULL,
    pressure_class integer NOT NULL,
    range integer NOT NULL
);


ALTER TABLE activity2pressure OWNER TO ajolma;

--
-- Name: COLUMN activity2pressure.range; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN activity2pressure.range IS 'distance of impact, 1 to 6';


--
-- Name: activity2impact_type_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE activity2impact_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE activity2impact_type_id_seq OWNER TO ajolma;

--
-- Name: activity2impact_type_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE activity2impact_type_id_seq OWNED BY activity2pressure.id;


--
-- Name: color_scales; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE color_scales (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE color_scales OWNER TO ajolma;

--
-- Name: ecosystem_components; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE ecosystem_components (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE ecosystem_components OWNER TO ajolma;

--
-- Name: TABLE ecosystem_components; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON TABLE ecosystem_components IS 'A realisation of something in table 1 of MSFD';


--
-- Name: ecosystem_components_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE ecosystem_components_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ecosystem_components_id_seq OWNER TO ajolma;

--
-- Name: ecosystem_components_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE ecosystem_components_id_seq OWNED BY ecosystem_components.id;


--
-- Name: impacts; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE impacts (
    id integer NOT NULL,
    activity2pressure integer NOT NULL,
    ecosystem_component integer NOT NULL,
    strength integer,
    belief integer
);


ALTER TABLE impacts OWNER TO ajolma;

--
-- Name: COLUMN impacts.strength; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN impacts.strength IS '0 to 4';


--
-- Name: COLUMN impacts.belief; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN impacts.belief IS '1 to 3';


--
-- Name: pressure_classes; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE pressure_classes (
    id integer NOT NULL,
    category integer NOT NULL,
    name text NOT NULL,
    ordr integer
);


ALTER TABLE pressure_classes OWNER TO ajolma;

--
-- Name: TABLE pressure_classes; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON TABLE pressure_classes IS 'Table 2, MSFD';


--
-- Name: impacts_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE impacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impacts_id_seq OWNER TO ajolma;

--
-- Name: impacts_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE impacts_id_seq OWNED BY pressure_classes.id;


--
-- Name: impacts_id_seq1; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE impacts_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impacts_id_seq1 OWNER TO ajolma;

--
-- Name: impacts_id_seq1; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE impacts_id_seq1 OWNED BY impacts.id;


--
-- Name: layer_classes; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE layer_classes (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE layer_classes OWNER TO ajolma;

--
-- Name: layers; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE layers (
    use integer NOT NULL,
    layer_class integer NOT NULL,
    id integer NOT NULL,
    rule_class integer DEFAULT 1 NOT NULL,
    descr text,
    style integer NOT NULL
);


ALTER TABLE layers OWNER TO ajolma;

--
-- Name: TABLE layers; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON TABLE layers IS 'Has similarities with data.datasets';


--
-- Name: layers_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE layers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE layers_id_seq OWNER TO ajolma;

--
-- Name: layers_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE layers_id_seq OWNED BY layer_classes.id;


--
-- Name: number_type; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE number_type (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE number_type OWNER TO ajolma;

--
-- Name: number_type_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE number_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE number_type_id_seq OWNER TO ajolma;

--
-- Name: number_type_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE number_type_id_seq OWNED BY number_type.id;


--
-- Name: ops; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE ops (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE ops OWNER TO ajolma;

--
-- Name: ops_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE ops_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ops_id_seq OWNER TO ajolma;

--
-- Name: ops_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE ops_id_seq OWNED BY ops.id;


--
-- Name: plan2use2layer_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE plan2use2layer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE plan2use2layer_id_seq OWNER TO ajolma;

--
-- Name: plan2use2layer_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE plan2use2layer_id_seq OWNED BY layers.id;


--
-- Name: uses; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE uses (
    id integer NOT NULL,
    plan integer NOT NULL,
    use_class integer NOT NULL
);


ALTER TABLE uses OWNER TO ajolma;

--
-- Name: plan2use_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE plan2use_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE plan2use_id_seq OWNER TO ajolma;

--
-- Name: plan2use_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE plan2use_id_seq OWNED BY uses.id;


--
-- Name: plans; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE plans (
    id integer NOT NULL,
    name text NOT NULL,
    schema text
);


ALTER TABLE plans OWNER TO ajolma;

--
-- Name: plans_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE plans_id_seq OWNER TO ajolma;

--
-- Name: plans_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE plans_id_seq OWNED BY plans.id;


--
-- Name: pressure_categories; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE pressure_categories (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE pressure_categories OWNER TO ajolma;

--
-- Name: TABLE pressure_categories; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON TABLE pressure_categories IS 'Table 2, MSFD';


--
-- Name: pressures_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE pressures_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pressures_id_seq OWNER TO ajolma;

--
-- Name: pressures_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE pressures_id_seq OWNED BY pressure_categories.id;


--
-- Name: rule_classes; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE rule_classes (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE rule_classes OWNER TO ajolma;

--
-- Name: rule_classes_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE rule_classes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rule_classes_id_seq OWNER TO ajolma;

--
-- Name: rule_classes_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE rule_classes_id_seq OWNED BY rule_classes.id;


--
-- Name: rules; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE rules (
    id integer NOT NULL,
    r_layer integer,
    op integer DEFAULT 1 NOT NULL,
    value double precision DEFAULT 1 NOT NULL,
    r_dataset integer,
    min_value double precision DEFAULT 0 NOT NULL,
    max_value double precision DEFAULT 1 NOT NULL,
    cookie text DEFAULT 'default'::text NOT NULL,
    made timestamp with time zone,
    value_at_min double precision DEFAULT 0 NOT NULL,
    value_at_max double precision DEFAULT 1 NOT NULL,
    weight double precision DEFAULT 1 NOT NULL,
    layer integer NOT NULL,
    value_type integer DEFAULT 1 NOT NULL
);


ALTER TABLE rules OWNER TO ajolma;

--
-- Name: COLUMN rules.r_layer; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.r_layer IS 'reference to other pul';


--
-- Name: COLUMN rules.value; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.value IS 'threshold, used together with op';


--
-- Name: COLUMN rules.r_dataset; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.r_dataset IS 'data for this this rule (alternative to reference pul)';


--
-- Name: COLUMN rules.value_at_min; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.value_at_min IS 'for additive and multiplicative rules. 0 to 1, less than value_at_max';


--
-- Name: COLUMN rules.value_at_max; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.value_at_max IS 'for additive and multiplicative rules. 0 to 1, greater than value_at_max';


--
-- Name: COLUMN rules.weight; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.weight IS 'for additive and multiplicative rules';


--
-- Name: COLUMN rules.layer; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.layer IS 'which layer this rule is used to create';


--
-- Name: COLUMN rules.value_type; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.value_type IS 'for sequential rules, type of column ''value''';


--
-- Name: rules_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rules_id_seq OWNER TO ajolma;

--
-- Name: rules_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE rules_id_seq OWNED BY rules.id;


--
-- Name: styles; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE styles (
    id integer NOT NULL,
    color_scale integer,
    min double precision,
    max double precision,
    classes integer,
    class_labels text
);


ALTER TABLE styles OWNER TO ajolma;

--
-- Name: styles_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE styles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE styles_id_seq OWNER TO ajolma;

--
-- Name: styles_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE styles_id_seq OWNED BY color_scales.id;


--
-- Name: styles_id_seq1; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE styles_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE styles_id_seq1 OWNER TO ajolma;

--
-- Name: styles_id_seq1; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE styles_id_seq1 OWNED BY styles.id;


--
-- Name: use_class2activity; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE use_class2activity (
    id integer NOT NULL,
    use_class integer NOT NULL,
    activity integer NOT NULL
);


ALTER TABLE use_class2activity OWNER TO ajolma;

--
-- Name: use2activity_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE use2activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE use2activity_id_seq OWNER TO ajolma;

--
-- Name: use2activity_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE use2activity_id_seq OWNED BY use_class2activity.id;


--
-- Name: use_classes; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE use_classes (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE use_classes OWNER TO ajolma;

--
-- Name: uses_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE uses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE uses_id_seq OWNER TO ajolma;

--
-- Name: uses_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE uses_id_seq OWNED BY use_classes.id;


SET search_path = data, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY data_models ALTER COLUMN id SET DEFAULT nextval('"data models_id_seq"'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY datasets ALTER COLUMN id SET DEFAULT nextval('datasets_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY layers ALTER COLUMN id SET DEFAULT nextval('remote_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY licenses ALTER COLUMN id SET DEFAULT nextval('licenses_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY organizations ALTER COLUMN id SET DEFAULT nextval('organizations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY units ALTER COLUMN id SET DEFAULT nextval('units_id_seq'::regclass);


SET search_path = tool, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY activities ALTER COLUMN id SET DEFAULT nextval('activities_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY activity2pressure ALTER COLUMN id SET DEFAULT nextval('activity2impact_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY color_scales ALTER COLUMN id SET DEFAULT nextval('styles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ecosystem_components ALTER COLUMN id SET DEFAULT nextval('ecosystem_components_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impacts ALTER COLUMN id SET DEFAULT nextval('impacts_id_seq1'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layer_classes ALTER COLUMN id SET DEFAULT nextval('layers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layers ALTER COLUMN id SET DEFAULT nextval('plan2use2layer_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY number_type ALTER COLUMN id SET DEFAULT nextval('number_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ops ALTER COLUMN id SET DEFAULT nextval('ops_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plans ALTER COLUMN id SET DEFAULT nextval('plans_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY pressure_categories ALTER COLUMN id SET DEFAULT nextval('pressures_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY pressure_classes ALTER COLUMN id SET DEFAULT nextval('impacts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rule_classes ALTER COLUMN id SET DEFAULT nextval('rule_classes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules ALTER COLUMN id SET DEFAULT nextval('rules_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY styles ALTER COLUMN id SET DEFAULT nextval('styles_id_seq1'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use_class2activity ALTER COLUMN id SET DEFAULT nextval('use2activity_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use_classes ALTER COLUMN id SET DEFAULT nextval('uses_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY uses ALTER COLUMN id SET DEFAULT nextval('plan2use_id_seq'::regclass);


SET search_path = data, pg_catalog;

--
-- Name: data models_pkey; Type: CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY data_models
    ADD CONSTRAINT "data models_pkey" PRIMARY KEY (id);


--
-- Name: data models_title_key; Type: CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY data_models
    ADD CONSTRAINT "data models_title_key" UNIQUE (name);


--
-- Name: datasets_name_key; Type: CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY datasets
    ADD CONSTRAINT datasets_name_key UNIQUE (name);


--
-- Name: datasets_pkey; Type: CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY datasets
    ADD CONSTRAINT datasets_pkey PRIMARY KEY (id);


--
-- Name: licenses_name_key; Type: CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY licenses
    ADD CONSTRAINT licenses_name_key UNIQUE (name);


--
-- Name: licenses_pkey; Type: CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY licenses
    ADD CONSTRAINT licenses_pkey PRIMARY KEY (id);


--
-- Name: organizations_name_key; Type: CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY organizations
    ADD CONSTRAINT organizations_name_key UNIQUE (name);


--
-- Name: organizations_pkey; Type: CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: remote_pkey; Type: CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT remote_pkey PRIMARY KEY (id);


--
-- Name: units_pkey; Type: CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY units
    ADD CONSTRAINT units_pkey PRIMARY KEY (id);


--
-- Name: units_title_key; Type: CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY units
    ADD CONSTRAINT units_title_key UNIQUE (name);


SET search_path = tool, pg_catalog;

--
-- Name: activities_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- Name: activity2impact_type_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY activity2pressure
    ADD CONSTRAINT activity2impact_type_pkey PRIMARY KEY (id);


--
-- Name: activity2pressure_activity_pressure_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY activity2pressure
    ADD CONSTRAINT activity2pressure_activity_pressure_key UNIQUE (activity, pressure_class);


--
-- Name: ecosystem_components_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ecosystem_components
    ADD CONSTRAINT ecosystem_components_pkey PRIMARY KEY (id);


--
-- Name: impacts_activity2pressure_ecosystem_component_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impacts
    ADD CONSTRAINT impacts_activity2pressure_ecosystem_component_key UNIQUE (activity2pressure, ecosystem_component);


--
-- Name: impacts_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY pressure_classes
    ADD CONSTRAINT impacts_pkey PRIMARY KEY (id);


--
-- Name: impacts_pkey1; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impacts
    ADD CONSTRAINT impacts_pkey1 PRIMARY KEY (id);


--
-- Name: impacts_title_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY pressure_classes
    ADD CONSTRAINT impacts_title_key UNIQUE (name);


--
-- Name: layers_data_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layer_classes
    ADD CONSTRAINT layers_data_key UNIQUE (name);


--
-- Name: layers_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layer_classes
    ADD CONSTRAINT layers_pkey PRIMARY KEY (id);


--
-- Name: number_type_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY number_type
    ADD CONSTRAINT number_type_pkey PRIMARY KEY (id);


--
-- Name: ops_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ops
    ADD CONSTRAINT ops_pkey PRIMARY KEY (id);


--
-- Name: plan2use2layer_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT plan2use2layer_pkey PRIMARY KEY (id);


--
-- Name: plan2use2layer_plan2use_layer_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT plan2use2layer_plan2use_layer_key UNIQUE (use, layer_class);


--
-- Name: plan2use_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY uses
    ADD CONSTRAINT plan2use_pkey PRIMARY KEY (id);


--
-- Name: plan2use_plan_use_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY uses
    ADD CONSTRAINT plan2use_plan_use_key UNIQUE (plan, use_class);


--
-- Name: plans_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plans
    ADD CONSTRAINT plans_pkey PRIMARY KEY (id);


--
-- Name: plans_title_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plans
    ADD CONSTRAINT plans_title_key UNIQUE (name);


--
-- Name: pressures_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY pressure_categories
    ADD CONSTRAINT pressures_pkey PRIMARY KEY (id);


--
-- Name: pressures_title_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY pressure_categories
    ADD CONSTRAINT pressures_title_key UNIQUE (name);


--
-- Name: rule_classes_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rule_classes
    ADD CONSTRAINT rule_classes_pkey PRIMARY KEY (id);


--
-- Name: rules_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_pkey PRIMARY KEY (id, cookie);


--
-- Name: styles_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY color_scales
    ADD CONSTRAINT styles_pkey PRIMARY KEY (id);


--
-- Name: styles_pkey1; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY styles
    ADD CONSTRAINT styles_pkey1 PRIMARY KEY (id);


--
-- Name: use2activity_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use_class2activity
    ADD CONSTRAINT use2activity_pkey PRIMARY KEY (id);


--
-- Name: use2activity_use_activity_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use_class2activity
    ADD CONSTRAINT use2activity_use_activity_key UNIQUE (use_class, activity);


--
-- Name: uses_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use_classes
    ADD CONSTRAINT uses_pkey PRIMARY KEY (id);


--
-- Name: uses_title_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use_classes
    ADD CONSTRAINT uses_title_key UNIQUE (name);


SET search_path = data, pg_catalog;

--
-- Name: datasets_custodian_fkey; Type: FK CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY datasets
    ADD CONSTRAINT datasets_custodian_fkey FOREIGN KEY (custodian) REFERENCES organizations(id);


--
-- Name: datasets_data model_fkey; Type: FK CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY datasets
    ADD CONSTRAINT "datasets_data model_fkey" FOREIGN KEY (data_model) REFERENCES data_models(id);


--
-- Name: datasets_is a part of_fkey; Type: FK CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY datasets
    ADD CONSTRAINT "datasets_is a part of_fkey" FOREIGN KEY (is_a_part_of) REFERENCES datasets(id);


--
-- Name: datasets_is derived from_fkey; Type: FK CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY datasets
    ADD CONSTRAINT "datasets_is derived from_fkey" FOREIGN KEY (is_derived_from) REFERENCES datasets(id);


--
-- Name: datasets_license_fkey; Type: FK CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY datasets
    ADD CONSTRAINT datasets_license_fkey FOREIGN KEY (license) REFERENCES licenses(id);


--
-- Name: datasets_style2_fkey; Type: FK CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY datasets
    ADD CONSTRAINT datasets_style2_fkey FOREIGN KEY (style) REFERENCES tool.styles(id);


--
-- Name: datasets_unit_fkey; Type: FK CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY datasets
    ADD CONSTRAINT datasets_unit_fkey FOREIGN KEY (unit) REFERENCES units(id);


SET search_path = tool, pg_catalog;

--
-- Name: activity2impact_type_activity_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY activity2pressure
    ADD CONSTRAINT activity2impact_type_activity_fkey FOREIGN KEY (activity) REFERENCES activities(id);


--
-- Name: activity2impact_type_impact_type_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY activity2pressure
    ADD CONSTRAINT activity2impact_type_impact_type_fkey FOREIGN KEY (pressure_class) REFERENCES pressure_classes(id);


--
-- Name: impacts_activity2impact_type_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impacts
    ADD CONSTRAINT impacts_activity2impact_type_fkey FOREIGN KEY (activity2pressure) REFERENCES activity2pressure(id);


--
-- Name: impacts_ecosystem_component_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impacts
    ADD CONSTRAINT impacts_ecosystem_component_fkey FOREIGN KEY (ecosystem_component) REFERENCES ecosystem_components(id);


--
-- Name: impacts_pressure_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY pressure_classes
    ADD CONSTRAINT impacts_pressure_fkey FOREIGN KEY (category) REFERENCES pressure_categories(id);


--
-- Name: layers_style2_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT layers_style2_fkey FOREIGN KEY (style) REFERENCES styles(id);


--
-- Name: plan2use2layer_plan2use_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT plan2use2layer_plan2use_fkey FOREIGN KEY (use) REFERENCES uses(id);


--
-- Name: plan2use2layer_rule_class_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT plan2use2layer_rule_class_fkey FOREIGN KEY (rule_class) REFERENCES rule_classes(id);


--
-- Name: plan2use_plan_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY uses
    ADD CONSTRAINT plan2use_plan_fkey FOREIGN KEY (plan) REFERENCES plans(id);


--
-- Name: plan2use_use_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY uses
    ADD CONSTRAINT plan2use_use_fkey FOREIGN KEY (use_class) REFERENCES use_classes(id);


--
-- Name: rules_plan2use2layer_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_plan2use2layer_fkey FOREIGN KEY (layer) REFERENCES layers(id);


--
-- Name: rules_r_dataset_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_r_dataset_fkey FOREIGN KEY (r_dataset) REFERENCES data.datasets(id);


--
-- Name: rules_r_layer_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_r_layer_fkey FOREIGN KEY (r_layer) REFERENCES layers(id);


--
-- Name: rules_r_op_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_r_op_fkey FOREIGN KEY (op) REFERENCES ops(id);


--
-- Name: rules_v_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_v_fkey FOREIGN KEY (value_type) REFERENCES number_type(id);


--
-- Name: styles_color_scale_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY styles
    ADD CONSTRAINT styles_color_scale_fkey FOREIGN KEY (color_scale) REFERENCES color_scales(id);


--
-- Name: use2activity_activity_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use_class2activity
    ADD CONSTRAINT use2activity_activity_fkey FOREIGN KEY (activity) REFERENCES activities(id);


--
-- Name: use2activity_use_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use_class2activity
    ADD CONSTRAINT use2activity_use_fkey FOREIGN KEY (use_class) REFERENCES use_classes(id);


--
-- Name: use2layer_layer_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT use2layer_layer_fkey FOREIGN KEY (layer_class) REFERENCES layer_classes(id);


--
-- Name: data; Type: ACL; Schema: -; Owner: ajolma
--

REVOKE ALL ON SCHEMA data FROM PUBLIC;
REVOKE ALL ON SCHEMA data FROM ajolma;
GRANT ALL ON SCHEMA data TO ajolma;
GRANT USAGE ON SCHEMA data TO PUBLIC;
GRANT USAGE ON SCHEMA data TO smartsea;


--
-- Name: tool; Type: ACL; Schema: -; Owner: ajolma
--

REVOKE ALL ON SCHEMA tool FROM PUBLIC;
REVOKE ALL ON SCHEMA tool FROM ajolma;
GRANT ALL ON SCHEMA tool TO ajolma;
GRANT USAGE ON SCHEMA tool TO PUBLIC;
GRANT ALL ON SCHEMA tool TO smartsea;


SET search_path = data, pg_catalog;

--
-- Name: data_models; Type: ACL; Schema: data; Owner: ajolma
--

REVOKE ALL ON TABLE data_models FROM PUBLIC;
REVOKE ALL ON TABLE data_models FROM ajolma;
GRANT ALL ON TABLE data_models TO ajolma;
GRANT ALL ON TABLE data_models TO smartsea;


--
-- Name: datasets; Type: ACL; Schema: data; Owner: ajolma
--

REVOKE ALL ON TABLE datasets FROM PUBLIC;
REVOKE ALL ON TABLE datasets FROM ajolma;
GRANT ALL ON TABLE datasets TO ajolma;
GRANT ALL ON TABLE datasets TO smartsea;


--
-- Name: datasets_id_seq; Type: ACL; Schema: data; Owner: ajolma
--

REVOKE ALL ON SEQUENCE datasets_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE datasets_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE datasets_id_seq TO ajolma;
GRANT ALL ON SEQUENCE datasets_id_seq TO smartsea;


--
-- Name: licenses; Type: ACL; Schema: data; Owner: ajolma
--

REVOKE ALL ON TABLE licenses FROM PUBLIC;
REVOKE ALL ON TABLE licenses FROM ajolma;
GRANT ALL ON TABLE licenses TO ajolma;
GRANT ALL ON TABLE licenses TO smartsea;


--
-- Name: organizations; Type: ACL; Schema: data; Owner: ajolma
--

REVOKE ALL ON TABLE organizations FROM PUBLIC;
REVOKE ALL ON TABLE organizations FROM ajolma;
GRANT ALL ON TABLE organizations TO ajolma;
GRANT ALL ON TABLE organizations TO smartsea;


--
-- Name: units; Type: ACL; Schema: data; Owner: ajolma
--

REVOKE ALL ON TABLE units FROM PUBLIC;
REVOKE ALL ON TABLE units FROM ajolma;
GRANT ALL ON TABLE units TO ajolma;
GRANT ALL ON TABLE units TO smartsea;


SET search_path = tool, pg_catalog;

--
-- Name: activities; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE activities FROM PUBLIC;
REVOKE ALL ON TABLE activities FROM ajolma;
GRANT ALL ON TABLE activities TO ajolma;
GRANT ALL ON TABLE activities TO smartsea;


--
-- Name: activities_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE activities_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE activities_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE activities_id_seq TO ajolma;
GRANT ALL ON SEQUENCE activities_id_seq TO smartsea;


--
-- Name: activity2pressure; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE activity2pressure FROM PUBLIC;
REVOKE ALL ON TABLE activity2pressure FROM ajolma;
GRANT ALL ON TABLE activity2pressure TO ajolma;
GRANT ALL ON TABLE activity2pressure TO smartsea;


--
-- Name: activity2impact_type_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE activity2impact_type_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE activity2impact_type_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE activity2impact_type_id_seq TO ajolma;
GRANT ALL ON SEQUENCE activity2impact_type_id_seq TO smartsea;


--
-- Name: color_scales; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE color_scales FROM PUBLIC;
REVOKE ALL ON TABLE color_scales FROM ajolma;
GRANT ALL ON TABLE color_scales TO ajolma;
GRANT ALL ON TABLE color_scales TO smartsea;


--
-- Name: ecosystem_components; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE ecosystem_components FROM PUBLIC;
REVOKE ALL ON TABLE ecosystem_components FROM ajolma;
GRANT ALL ON TABLE ecosystem_components TO ajolma;
GRANT ALL ON TABLE ecosystem_components TO smartsea;


--
-- Name: impacts; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE impacts FROM PUBLIC;
REVOKE ALL ON TABLE impacts FROM ajolma;
GRANT ALL ON TABLE impacts TO ajolma;
GRANT ALL ON TABLE impacts TO smartsea;


--
-- Name: pressure_classes; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE pressure_classes FROM PUBLIC;
REVOKE ALL ON TABLE pressure_classes FROM ajolma;
GRANT ALL ON TABLE pressure_classes TO ajolma;
GRANT SELECT ON TABLE pressure_classes TO PUBLIC;
GRANT ALL ON TABLE pressure_classes TO smartsea;


--
-- Name: impacts_id_seq1; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE impacts_id_seq1 FROM PUBLIC;
REVOKE ALL ON SEQUENCE impacts_id_seq1 FROM ajolma;
GRANT ALL ON SEQUENCE impacts_id_seq1 TO ajolma;
GRANT ALL ON SEQUENCE impacts_id_seq1 TO smartsea;


--
-- Name: layer_classes; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE layer_classes FROM PUBLIC;
REVOKE ALL ON TABLE layer_classes FROM ajolma;
GRANT ALL ON TABLE layer_classes TO ajolma;
GRANT SELECT ON TABLE layer_classes TO PUBLIC;
GRANT ALL ON TABLE layer_classes TO smartsea;


--
-- Name: layers; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE layers FROM PUBLIC;
REVOKE ALL ON TABLE layers FROM ajolma;
GRANT ALL ON TABLE layers TO ajolma;
GRANT SELECT ON TABLE layers TO PUBLIC;
GRANT ALL ON TABLE layers TO smartsea;


--
-- Name: layers_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE layers_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE layers_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE layers_id_seq TO ajolma;
GRANT ALL ON SEQUENCE layers_id_seq TO smartsea;


--
-- Name: number_type; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE number_type FROM PUBLIC;
REVOKE ALL ON TABLE number_type FROM ajolma;
GRANT ALL ON TABLE number_type TO ajolma;
GRANT ALL ON TABLE number_type TO smartsea;


--
-- Name: number_type_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE number_type_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE number_type_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE number_type_id_seq TO ajolma;
GRANT ALL ON SEQUENCE number_type_id_seq TO smartsea;


--
-- Name: ops; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE ops FROM PUBLIC;
REVOKE ALL ON TABLE ops FROM ajolma;
GRANT ALL ON TABLE ops TO ajolma;
GRANT ALL ON TABLE ops TO smartsea;


--
-- Name: plan2use2layer_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE plan2use2layer_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE plan2use2layer_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE plan2use2layer_id_seq TO ajolma;
GRANT ALL ON SEQUENCE plan2use2layer_id_seq TO smartsea;


--
-- Name: uses; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE uses FROM PUBLIC;
REVOKE ALL ON TABLE uses FROM ajolma;
GRANT ALL ON TABLE uses TO ajolma;
GRANT ALL ON TABLE uses TO smartsea;


--
-- Name: plan2use_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE plan2use_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE plan2use_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE plan2use_id_seq TO ajolma;
GRANT ALL ON SEQUENCE plan2use_id_seq TO smartsea;


--
-- Name: plans; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE plans FROM PUBLIC;
REVOKE ALL ON TABLE plans FROM ajolma;
GRANT ALL ON TABLE plans TO ajolma;
GRANT SELECT ON TABLE plans TO PUBLIC;
GRANT ALL ON TABLE plans TO smartsea;


--
-- Name: plans_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE plans_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE plans_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE plans_id_seq TO ajolma;
GRANT ALL ON SEQUENCE plans_id_seq TO smartsea;


--
-- Name: pressure_categories; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE pressure_categories FROM PUBLIC;
REVOKE ALL ON TABLE pressure_categories FROM ajolma;
GRANT ALL ON TABLE pressure_categories TO ajolma;
GRANT SELECT ON TABLE pressure_categories TO PUBLIC;
GRANT ALL ON TABLE pressure_categories TO smartsea;


--
-- Name: rule_classes; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE rule_classes FROM PUBLIC;
REVOKE ALL ON TABLE rule_classes FROM ajolma;
GRANT ALL ON TABLE rule_classes TO ajolma;
GRANT ALL ON TABLE rule_classes TO smartsea;


--
-- Name: rules; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE rules FROM PUBLIC;
REVOKE ALL ON TABLE rules FROM ajolma;
GRANT ALL ON TABLE rules TO ajolma;
GRANT ALL ON TABLE rules TO smartsea;


--
-- Name: rules_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE rules_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE rules_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE rules_id_seq TO ajolma;
GRANT ALL ON SEQUENCE rules_id_seq TO smartsea;


--
-- Name: styles; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE styles FROM PUBLIC;
REVOKE ALL ON TABLE styles FROM ajolma;
GRANT ALL ON TABLE styles TO ajolma;
GRANT ALL ON TABLE styles TO smartsea;


--
-- Name: styles_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE styles_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE styles_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE styles_id_seq TO ajolma;
GRANT ALL ON SEQUENCE styles_id_seq TO smartsea;


--
-- Name: styles_id_seq1; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE styles_id_seq1 FROM PUBLIC;
REVOKE ALL ON SEQUENCE styles_id_seq1 FROM ajolma;
GRANT ALL ON SEQUENCE styles_id_seq1 TO ajolma;
GRANT ALL ON SEQUENCE styles_id_seq1 TO smartsea;


--
-- Name: use_class2activity; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE use_class2activity FROM PUBLIC;
REVOKE ALL ON TABLE use_class2activity FROM ajolma;
GRANT ALL ON TABLE use_class2activity TO ajolma;
GRANT ALL ON TABLE use_class2activity TO smartsea;


--
-- Name: use2activity_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE use2activity_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE use2activity_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE use2activity_id_seq TO ajolma;
GRANT ALL ON SEQUENCE use2activity_id_seq TO smartsea;


--
-- Name: use_classes; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE use_classes FROM PUBLIC;
REVOKE ALL ON TABLE use_classes FROM ajolma;
GRANT ALL ON TABLE use_classes TO ajolma;
GRANT SELECT ON TABLE use_classes TO PUBLIC;
GRANT ALL ON TABLE use_classes TO smartsea;


--
-- Name: uses_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE uses_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE uses_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE uses_id_seq TO ajolma;
GRANT ALL ON SEQUENCE uses_id_seq TO smartsea;


--
-- PostgreSQL database dump complete
--

