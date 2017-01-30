--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

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
-- Name: data_models; Type: TABLE; Schema: data; Owner: ajolma; Tablespace: 
--

CREATE TABLE data_models (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE data.data_models OWNER TO ajolma;

--
-- Name: data models_id_seq; Type: SEQUENCE; Schema: data; Owner: ajolma
--

CREATE SEQUENCE "data models_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE data."data models_id_seq" OWNER TO ajolma;

--
-- Name: data models_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: ajolma
--

ALTER SEQUENCE "data models_id_seq" OWNED BY data_models.id;


--
-- Name: datasets; Type: TABLE; Schema: data; Owner: ajolma; Tablespace: 
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
    unit integer
);


ALTER TABLE data.datasets OWNER TO ajolma;

--
-- Name: datasets_id_seq; Type: SEQUENCE; Schema: data; Owner: ajolma
--

CREATE SEQUENCE datasets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE data.datasets_id_seq OWNER TO ajolma;

--
-- Name: datasets_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: ajolma
--

ALTER SEQUENCE datasets_id_seq OWNED BY datasets.id;


--
-- Name: layers; Type: TABLE; Schema: data; Owner: ajolma; Tablespace: 
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


ALTER TABLE data.layers OWNER TO ajolma;

--
-- Name: TABLE layers; Type: COMMENT; Schema: data; Owner: ajolma
--

COMMENT ON TABLE layers IS 'remote layers';


--
-- Name: licenses; Type: TABLE; Schema: data; Owner: ajolma; Tablespace: 
--

CREATE TABLE licenses (
    id integer NOT NULL,
    name text NOT NULL,
    url text
);


ALTER TABLE data.licenses OWNER TO ajolma;

--
-- Name: licenses_id_seq; Type: SEQUENCE; Schema: data; Owner: ajolma
--

CREATE SEQUENCE licenses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE data.licenses_id_seq OWNER TO ajolma;

--
-- Name: licenses_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: ajolma
--

ALTER SEQUENCE licenses_id_seq OWNED BY licenses.id;


--
-- Name: organizations; Type: TABLE; Schema: data; Owner: ajolma; Tablespace: 
--

CREATE TABLE organizations (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE data.organizations OWNER TO ajolma;

--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: data; Owner: ajolma
--

CREATE SEQUENCE organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE data.organizations_id_seq OWNER TO ajolma;

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


ALTER TABLE data.remote_id_seq OWNER TO ajolma;

--
-- Name: remote_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: ajolma
--

ALTER SEQUENCE remote_id_seq OWNED BY layers.id;


--
-- Name: units; Type: TABLE; Schema: data; Owner: ajolma; Tablespace: 
--

CREATE TABLE units (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE data.units OWNER TO ajolma;

--
-- Name: units_id_seq; Type: SEQUENCE; Schema: data; Owner: ajolma
--

CREATE SEQUENCE units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE data.units_id_seq OWNER TO ajolma;

--
-- Name: units_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: ajolma
--

ALTER SEQUENCE units_id_seq OWNED BY units.id;


SET search_path = tool, pg_catalog;

--
-- Name: activities; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE activities (
    id integer NOT NULL,
    title text NOT NULL,
    "order" integer DEFAULT 1 NOT NULL
);


ALTER TABLE tool.activities OWNER TO ajolma;

--
-- Name: activities_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE activities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tool.activities_id_seq OWNER TO ajolma;

--
-- Name: activities_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE activities_id_seq OWNED BY activities.id;


--
-- Name: activity2pressure; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE activity2pressure (
    id integer NOT NULL,
    activity integer NOT NULL,
    pressure integer NOT NULL,
    range integer NOT NULL
);


ALTER TABLE tool.activity2pressure OWNER TO ajolma;

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


ALTER TABLE tool.activity2impact_type_id_seq OWNER TO ajolma;

--
-- Name: activity2impact_type_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE activity2impact_type_id_seq OWNED BY activity2pressure.id;


--
-- Name: ecosystem_components; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE ecosystem_components (
    id integer NOT NULL,
    title text NOT NULL
);


ALTER TABLE tool.ecosystem_components OWNER TO ajolma;

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


ALTER TABLE tool.ecosystem_components_id_seq OWNER TO ajolma;

--
-- Name: ecosystem_components_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE ecosystem_components_id_seq OWNED BY ecosystem_components.id;


--
-- Name: impacts; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE impacts (
    id integer NOT NULL,
    activity2pressure integer NOT NULL,
    ecosystem_component integer NOT NULL,
    strength integer,
    belief integer
);


ALTER TABLE tool.impacts OWNER TO ajolma;

--
-- Name: COLUMN impacts.strength; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN impacts.strength IS '0 to 4';


--
-- Name: COLUMN impacts.belief; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN impacts.belief IS '1 to 3';


--
-- Name: pressures; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE pressures (
    id integer NOT NULL,
    category integer NOT NULL,
    title text NOT NULL,
    "order" integer
);


ALTER TABLE tool.pressures OWNER TO ajolma;

--
-- Name: TABLE pressures; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON TABLE pressures IS 'Table 2, MSFD';


--
-- Name: impacts_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE impacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tool.impacts_id_seq OWNER TO ajolma;

--
-- Name: impacts_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE impacts_id_seq OWNED BY pressures.id;


--
-- Name: impacts_id_seq1; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE impacts_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tool.impacts_id_seq1 OWNER TO ajolma;

--
-- Name: impacts_id_seq1; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE impacts_id_seq1 OWNED BY impacts.id;


--
-- Name: layers; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE layers (
    id integer NOT NULL,
    title text NOT NULL
);


ALTER TABLE tool.layers OWNER TO ajolma;

--
-- Name: layers_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE layers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tool.layers_id_seq OWNER TO ajolma;

--
-- Name: layers_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE layers_id_seq OWNED BY layers.id;


--
-- Name: ops; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE ops (
    id integer NOT NULL,
    op text NOT NULL
);


ALTER TABLE tool.ops OWNER TO ajolma;

--
-- Name: ops_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE ops_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tool.ops_id_seq OWNER TO ajolma;

--
-- Name: ops_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE ops_id_seq OWNED BY ops.id;


--
-- Name: plan2use; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE plan2use (
    id integer NOT NULL,
    plan integer NOT NULL,
    use integer NOT NULL
);


ALTER TABLE tool.plan2use OWNER TO ajolma;

--
-- Name: plan2use2layer; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE plan2use2layer (
    plan2use integer NOT NULL,
    layer integer NOT NULL,
    id integer NOT NULL,
    rule_class integer DEFAULT 1 NOT NULL
);


ALTER TABLE tool.plan2use2layer OWNER TO ajolma;

--
-- Name: plan2use2layer_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE plan2use2layer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tool.plan2use2layer_id_seq OWNER TO ajolma;

--
-- Name: plan2use2layer_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE plan2use2layer_id_seq OWNED BY plan2use2layer.id;


--
-- Name: plan2use_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE plan2use_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tool.plan2use_id_seq OWNER TO ajolma;

--
-- Name: plan2use_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE plan2use_id_seq OWNED BY plan2use.id;


--
-- Name: plans; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE plans (
    id integer NOT NULL,
    title text NOT NULL,
    schema text
);


ALTER TABLE tool.plans OWNER TO ajolma;

--
-- Name: plans_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tool.plans_id_seq OWNER TO ajolma;

--
-- Name: plans_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE plans_id_seq OWNED BY plans.id;


--
-- Name: pressure_categories; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE pressure_categories (
    id integer NOT NULL,
    title text NOT NULL
);


ALTER TABLE tool.pressure_categories OWNER TO ajolma;

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


ALTER TABLE tool.pressures_id_seq OWNER TO ajolma;

--
-- Name: pressures_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE pressures_id_seq OWNED BY pressure_categories.id;


--
-- Name: rule_classes; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE rule_classes (
    id integer NOT NULL,
    title text NOT NULL
);


ALTER TABLE tool.rule_classes OWNER TO ajolma;

--
-- Name: rule_classes_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE rule_classes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tool.rule_classes_id_seq OWNER TO ajolma;

--
-- Name: rule_classes_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE rule_classes_id_seq OWNED BY rule_classes.id;


--
-- Name: rules; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE rules (
    id integer NOT NULL,
    reduce boolean DEFAULT true NOT NULL,
    r_use integer,
    r_layer integer,
    r_plan integer,
    op integer,
    value double precision,
    r_dataset integer,
    min_value double precision,
    max_value double precision,
    my_index integer DEFAULT 1 NOT NULL,
    value_type text,
    cookie text DEFAULT 'default'::text NOT NULL,
    made timestamp with time zone,
    value_at_min double precision DEFAULT 0,
    value_at_max double precision DEFAULT 1,
    weight double precision DEFAULT 1,
    plan2use2layer integer NOT NULL
);


ALTER TABLE tool.rules OWNER TO ajolma;

--
-- Name: COLUMN rules.value; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.value IS 'threshold';


--
-- Name: COLUMN rules.value_at_min; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.value_at_min IS '0 to 1, less than value_at_max';


--
-- Name: COLUMN rules.value_at_max; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.value_at_max IS '0 to 1, greater than value_at_max';


--
-- Name: rules_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tool.rules_id_seq OWNER TO ajolma;

--
-- Name: rules_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE rules_id_seq OWNED BY rules.id;


--
-- Name: use2activity; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE use2activity (
    id integer NOT NULL,
    use integer NOT NULL,
    activity integer NOT NULL
);


ALTER TABLE tool.use2activity OWNER TO ajolma;

--
-- Name: use2activity_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE use2activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tool.use2activity_id_seq OWNER TO ajolma;

--
-- Name: use2activity_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE use2activity_id_seq OWNED BY use2activity.id;


--
-- Name: uses; Type: TABLE; Schema: tool; Owner: ajolma; Tablespace: 
--

CREATE TABLE uses (
    id integer NOT NULL,
    title text NOT NULL,
    current_allocation integer
);


ALTER TABLE tool.uses OWNER TO ajolma;

--
-- Name: uses_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE uses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tool.uses_id_seq OWNER TO ajolma;

--
-- Name: uses_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE uses_id_seq OWNED BY uses.id;


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

ALTER TABLE ONLY ecosystem_components ALTER COLUMN id SET DEFAULT nextval('ecosystem_components_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impacts ALTER COLUMN id SET DEFAULT nextval('impacts_id_seq1'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layers ALTER COLUMN id SET DEFAULT nextval('layers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ops ALTER COLUMN id SET DEFAULT nextval('ops_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plan2use ALTER COLUMN id SET DEFAULT nextval('plan2use_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plan2use2layer ALTER COLUMN id SET DEFAULT nextval('plan2use2layer_id_seq'::regclass);


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

ALTER TABLE ONLY pressures ALTER COLUMN id SET DEFAULT nextval('impacts_id_seq'::regclass);


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

ALTER TABLE ONLY use2activity ALTER COLUMN id SET DEFAULT nextval('use2activity_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY uses ALTER COLUMN id SET DEFAULT nextval('uses_id_seq'::regclass);


SET search_path = data, pg_catalog;

--
-- Name: data models_pkey; Type: CONSTRAINT; Schema: data; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY data_models
    ADD CONSTRAINT "data models_pkey" PRIMARY KEY (id);


--
-- Name: data models_title_key; Type: CONSTRAINT; Schema: data; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY data_models
    ADD CONSTRAINT "data models_title_key" UNIQUE (name);


--
-- Name: datasets_name_key; Type: CONSTRAINT; Schema: data; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY datasets
    ADD CONSTRAINT datasets_name_key UNIQUE (name);


--
-- Name: datasets_pkey; Type: CONSTRAINT; Schema: data; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY datasets
    ADD CONSTRAINT datasets_pkey PRIMARY KEY (id);


--
-- Name: licenses_name_key; Type: CONSTRAINT; Schema: data; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY licenses
    ADD CONSTRAINT licenses_name_key UNIQUE (name);


--
-- Name: licenses_pkey; Type: CONSTRAINT; Schema: data; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY licenses
    ADD CONSTRAINT licenses_pkey PRIMARY KEY (id);


--
-- Name: organizations_name_key; Type: CONSTRAINT; Schema: data; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY organizations
    ADD CONSTRAINT organizations_name_key UNIQUE (name);


--
-- Name: organizations_pkey; Type: CONSTRAINT; Schema: data; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: remote_pkey; Type: CONSTRAINT; Schema: data; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT remote_pkey PRIMARY KEY (id);


--
-- Name: units_pkey; Type: CONSTRAINT; Schema: data; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY units
    ADD CONSTRAINT units_pkey PRIMARY KEY (id);


--
-- Name: units_title_key; Type: CONSTRAINT; Schema: data; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY units
    ADD CONSTRAINT units_title_key UNIQUE (name);


SET search_path = tool, pg_catalog;

--
-- Name: activities_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- Name: activity2impact_type_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY activity2pressure
    ADD CONSTRAINT activity2impact_type_pkey PRIMARY KEY (id);


--
-- Name: activity2pressure_activity_pressure_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY activity2pressure
    ADD CONSTRAINT activity2pressure_activity_pressure_key UNIQUE (activity, pressure);


--
-- Name: ecosystem_components_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY ecosystem_components
    ADD CONSTRAINT ecosystem_components_pkey PRIMARY KEY (id);


--
-- Name: impacts_activity2pressure_ecosystem_component_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY impacts
    ADD CONSTRAINT impacts_activity2pressure_ecosystem_component_key UNIQUE (activity2pressure, ecosystem_component);


--
-- Name: impacts_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY pressures
    ADD CONSTRAINT impacts_pkey PRIMARY KEY (id);


--
-- Name: impacts_pkey1; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY impacts
    ADD CONSTRAINT impacts_pkey1 PRIMARY KEY (id);


--
-- Name: impacts_title_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY pressures
    ADD CONSTRAINT impacts_title_key UNIQUE (title);


--
-- Name: layers_data_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT layers_data_key UNIQUE (title);


--
-- Name: layers_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT layers_pkey PRIMARY KEY (id);


--
-- Name: ops_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY ops
    ADD CONSTRAINT ops_pkey PRIMARY KEY (id);


--
-- Name: plan2use2layer_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY plan2use2layer
    ADD CONSTRAINT plan2use2layer_pkey PRIMARY KEY (id);


--
-- Name: plan2use2layer_plan2use_layer_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY plan2use2layer
    ADD CONSTRAINT plan2use2layer_plan2use_layer_key UNIQUE (plan2use, layer);


--
-- Name: plan2use_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY plan2use
    ADD CONSTRAINT plan2use_pkey PRIMARY KEY (id);


--
-- Name: plan2use_plan_use_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY plan2use
    ADD CONSTRAINT plan2use_plan_use_key UNIQUE (plan, use);


--
-- Name: plans_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY plans
    ADD CONSTRAINT plans_pkey PRIMARY KEY (id);


--
-- Name: plans_title_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY plans
    ADD CONSTRAINT plans_title_key UNIQUE (title);


--
-- Name: pressures_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY pressure_categories
    ADD CONSTRAINT pressures_pkey PRIMARY KEY (id);


--
-- Name: pressures_title_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY pressure_categories
    ADD CONSTRAINT pressures_title_key UNIQUE (title);


--
-- Name: rule_classes_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY rule_classes
    ADD CONSTRAINT rule_classes_pkey PRIMARY KEY (id);


--
-- Name: rules_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_pkey PRIMARY KEY (id, cookie);


--
-- Name: use2activity_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY use2activity
    ADD CONSTRAINT use2activity_pkey PRIMARY KEY (id);


--
-- Name: use2activity_use_activity_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY use2activity
    ADD CONSTRAINT use2activity_use_activity_key UNIQUE (use, activity);


--
-- Name: uses_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY uses
    ADD CONSTRAINT uses_pkey PRIMARY KEY (id);


--
-- Name: uses_title_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma; Tablespace: 
--

ALTER TABLE ONLY uses
    ADD CONSTRAINT uses_title_key UNIQUE (title);


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
    ADD CONSTRAINT activity2impact_type_impact_type_fkey FOREIGN KEY (pressure) REFERENCES pressures(id);


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

ALTER TABLE ONLY pressures
    ADD CONSTRAINT impacts_pressure_fkey FOREIGN KEY (category) REFERENCES pressure_categories(id);


--
-- Name: plan2use2layer_plan2use_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plan2use2layer
    ADD CONSTRAINT plan2use2layer_plan2use_fkey FOREIGN KEY (plan2use) REFERENCES plan2use(id);


--
-- Name: plan2use2layer_rule_class_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plan2use2layer
    ADD CONSTRAINT plan2use2layer_rule_class_fkey FOREIGN KEY (rule_class) REFERENCES rule_classes(id);


--
-- Name: plan2use_plan_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plan2use
    ADD CONSTRAINT plan2use_plan_fkey FOREIGN KEY (plan) REFERENCES plans(id);


--
-- Name: plan2use_use_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plan2use
    ADD CONSTRAINT plan2use_use_fkey FOREIGN KEY (use) REFERENCES uses(id);


--
-- Name: rules_plan2use2layer_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_plan2use2layer_fkey FOREIGN KEY (plan2use2layer) REFERENCES plan2use2layer(id);


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
-- Name: rules_r_plan_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_r_plan_fkey FOREIGN KEY (r_plan) REFERENCES plans(id);


--
-- Name: rules_r_use_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_r_use_fkey FOREIGN KEY (r_use) REFERENCES uses(id);


--
-- Name: use2activity_activity_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use2activity
    ADD CONSTRAINT use2activity_activity_fkey FOREIGN KEY (activity) REFERENCES activities(id);


--
-- Name: use2activity_use_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use2activity
    ADD CONSTRAINT use2activity_use_fkey FOREIGN KEY (use) REFERENCES uses(id);


--
-- Name: use2layer_layer_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plan2use2layer
    ADD CONSTRAINT use2layer_layer_fkey FOREIGN KEY (layer) REFERENCES layers(id);


--
-- Name: uses_current_allocation_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY uses
    ADD CONSTRAINT uses_current_allocation_fkey FOREIGN KEY (current_allocation) REFERENCES data.datasets(id);


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
-- Name: pressures; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE pressures FROM PUBLIC;
REVOKE ALL ON TABLE pressures FROM ajolma;
GRANT ALL ON TABLE pressures TO ajolma;
GRANT SELECT ON TABLE pressures TO PUBLIC;
GRANT ALL ON TABLE pressures TO smartsea;


--
-- Name: impacts_id_seq1; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE impacts_id_seq1 FROM PUBLIC;
REVOKE ALL ON SEQUENCE impacts_id_seq1 FROM ajolma;
GRANT ALL ON SEQUENCE impacts_id_seq1 TO ajolma;
GRANT ALL ON SEQUENCE impacts_id_seq1 TO smartsea;


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
-- Name: ops; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE ops FROM PUBLIC;
REVOKE ALL ON TABLE ops FROM ajolma;
GRANT ALL ON TABLE ops TO ajolma;
GRANT ALL ON TABLE ops TO smartsea;


--
-- Name: plan2use; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE plan2use FROM PUBLIC;
REVOKE ALL ON TABLE plan2use FROM ajolma;
GRANT ALL ON TABLE plan2use TO ajolma;
GRANT ALL ON TABLE plan2use TO smartsea;


--
-- Name: plan2use2layer; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE plan2use2layer FROM PUBLIC;
REVOKE ALL ON TABLE plan2use2layer FROM ajolma;
GRANT ALL ON TABLE plan2use2layer TO ajolma;
GRANT SELECT ON TABLE plan2use2layer TO PUBLIC;
GRANT ALL ON TABLE plan2use2layer TO smartsea;


--
-- Name: plan2use2layer_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE plan2use2layer_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE plan2use2layer_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE plan2use2layer_id_seq TO ajolma;
GRANT ALL ON SEQUENCE plan2use2layer_id_seq TO smartsea;


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
-- Name: use2activity; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE use2activity FROM PUBLIC;
REVOKE ALL ON TABLE use2activity FROM ajolma;
GRANT ALL ON TABLE use2activity TO ajolma;
GRANT ALL ON TABLE use2activity TO smartsea;


--
-- Name: use2activity_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE use2activity_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE use2activity_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE use2activity_id_seq TO ajolma;
GRANT ALL ON SEQUENCE use2activity_id_seq TO smartsea;


--
-- Name: uses; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE uses FROM PUBLIC;
REVOKE ALL ON TABLE uses FROM ajolma;
GRANT ALL ON TABLE uses TO ajolma;
GRANT SELECT ON TABLE uses TO PUBLIC;
GRANT ALL ON TABLE uses TO smartsea;


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

