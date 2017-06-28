--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.7
-- Dumped by pg_dump version 9.5.7

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

COMMENT ON SCHEMA tool IS 'Core tables';


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
-- Name: data_models_id_seq; Type: SEQUENCE; Schema: data; Owner: ajolma
--

CREATE SEQUENCE data_models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE data_models_id_seq OWNER TO ajolma;

--
-- Name: data_models_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: ajolma
--

ALTER SEQUENCE data_models_id_seq OWNED BY data_models.id;


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
    style integer,
    db_table text,
    min_value double precision,
    max_value double precision,
    data_type integer,
    class_semantics text
);


ALTER TABLE datasets OWNER TO ajolma;

--
-- Name: COLUMN datasets.style; Type: COMMENT; Schema: data; Owner: ajolma
--

COMMENT ON COLUMN datasets.style IS 'required if path is not null, ie real data';


--
-- Name: COLUMN datasets.db_table; Type: COMMENT; Schema: data; Owner: ajolma
--

COMMENT ON COLUMN datasets.db_table IS 'For raster datasets: the table from it was created';


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
-- Name: pressures; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE pressures (
    id integer NOT NULL,
    activity integer NOT NULL,
    pressure_class integer NOT NULL,
    range integer NOT NULL
);


ALTER TABLE pressures OWNER TO ajolma;

--
-- Name: COLUMN pressures.range; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN pressures.range IS 'distance of impact, 1 to 6';


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

ALTER SEQUENCE activity2impact_type_id_seq OWNED BY pressures.id;


--
-- Name: beliefs; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE beliefs (
    id integer NOT NULL,
    description text,
    value integer DEFAULT 2 NOT NULL
);


ALTER TABLE beliefs OWNER TO ajolma;

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
    name text NOT NULL,
    distribution integer,
    style integer
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
-- Name: impact_computation_methods; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE impact_computation_methods (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE impact_computation_methods OWNER TO ajolma;

--
-- Name: impact_comp_method_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE impact_comp_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impact_comp_method_id_seq OWNER TO ajolma;

--
-- Name: impact_comp_method_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE impact_comp_method_id_seq OWNED BY impact_computation_methods.id;


--
-- Name: impact_layer2ecosystem_component; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE impact_layer2ecosystem_component (
    impact_layer integer NOT NULL,
    ecosystem_component integer NOT NULL,
    id integer NOT NULL
);


ALTER TABLE impact_layer2ecosystem_component OWNER TO ajolma;

--
-- Name: impact_layer2ecosystem_component_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE impact_layer2ecosystem_component_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impact_layer2ecosystem_component_id_seq OWNER TO ajolma;

--
-- Name: impact_layer2ecosystem_component_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE impact_layer2ecosystem_component_id_seq OWNED BY impact_layer2ecosystem_component.id;


--
-- Name: impact_layers; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE impact_layers (
    super integer NOT NULL,
    allocation integer NOT NULL,
    computation_method integer NOT NULL
);


ALTER TABLE impact_layers OWNER TO ajolma;

--
-- Name: impact_strengths; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE impact_strengths (
    id integer NOT NULL,
    recovery text,
    extent text,
    resilience text,
    temporal_extent text,
    value integer DEFAULT 2 NOT NULL
);


ALTER TABLE impact_strengths OWNER TO ajolma;

--
-- Name: COLUMN impact_strengths.recovery; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN impact_strengths.recovery IS 'palautuminen';


--
-- Name: COLUMN impact_strengths.extent; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN impact_strengths.extent IS 'vaikutus ekosysteemiin';


--
-- Name: COLUMN impact_strengths.resilience; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN impact_strengths.resilience IS 'ekosysteemin kyky sietää painetta';


--
-- Name: COLUMN impact_strengths.temporal_extent; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN impact_strengths.temporal_extent IS 'ajallinen ulottuvuus';


--
-- Name: impacts; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE impacts (
    id integer NOT NULL,
    pressure integer NOT NULL,
    ecosystem_component integer NOT NULL,
    strength integer,
    belief integer
);


ALTER TABLE impacts OWNER TO ajolma;

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
    descr text,
    style integer NOT NULL,
    rule_system integer NOT NULL,
    owner text
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
-- Name: number_types; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE number_types (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE number_types OWNER TO ajolma;

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

ALTER SEQUENCE number_type_id_seq OWNED BY number_types.id;


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
-- Name: plan2dataset_extra; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE plan2dataset_extra (
    plan integer NOT NULL,
    dataset integer NOT NULL,
    id integer NOT NULL
);


ALTER TABLE plan2dataset_extra OWNER TO ajolma;

--
-- Name: TABLE plan2dataset_extra; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON TABLE plan2dataset_extra IS 'Extra datasets in plan''s view.';


--
-- Name: plan2dataset_extra_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE plan2dataset_extra_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE plan2dataset_extra_id_seq OWNER TO ajolma;

--
-- Name: plan2dataset_extra_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE plan2dataset_extra_id_seq OWNED BY plan2dataset_extra.id;


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
    use_class integer NOT NULL,
    owner text
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
    schema text,
    owner text
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
-- Name: ranges; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE ranges (
    id integer NOT NULL,
    d double precision NOT NULL
);


ALTER TABLE ranges OWNER TO ajolma;

--
-- Name: COLUMN ranges.d; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN ranges.d IS 'Distance from activity to which pressure is caused [m]';


--
-- Name: rule_classes; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE rule_classes (
    id integer NOT NULL,
    name text NOT NULL,
    labels text
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
-- Name: rule_systems; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE rule_systems (
    id integer NOT NULL,
    rule_class integer NOT NULL
);


ALTER TABLE rule_systems OWNER TO ajolma;

--
-- Name: rule_systems_id_seq; Type: SEQUENCE; Schema: tool; Owner: ajolma
--

CREATE SEQUENCE rule_systems_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rule_systems_id_seq OWNER TO ajolma;

--
-- Name: rule_systems_id_seq; Type: SEQUENCE OWNED BY; Schema: tool; Owner: ajolma
--

ALTER SEQUENCE rule_systems_id_seq OWNED BY rule_systems.id;


--
-- Name: rules; Type: TABLE; Schema: tool; Owner: ajolma
--

CREATE TABLE rules (
    id integer NOT NULL,
    layer integer,
    op integer DEFAULT 1 NOT NULL,
    value double precision DEFAULT 1 NOT NULL,
    dataset integer,
    min_value double precision DEFAULT 0 NOT NULL,
    max_value double precision DEFAULT 1 NOT NULL,
    cookie text DEFAULT 'default'::text NOT NULL,
    made timestamp with time zone,
    value_at_min double precision DEFAULT 0 NOT NULL,
    value_at_max double precision DEFAULT 1 NOT NULL,
    weight double precision DEFAULT 1 NOT NULL,
    rule_system integer NOT NULL
);


ALTER TABLE rules OWNER TO ajolma;

--
-- Name: COLUMN rules.layer; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.layer IS 'data for this this rule (alternative to r_dataset)';


--
-- Name: COLUMN rules.value; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.value IS 'threshold, used together with op';


--
-- Name: COLUMN rules.dataset; Type: COMMENT; Schema: tool; Owner: ajolma
--

COMMENT ON COLUMN rules.dataset IS 'data for this this rule (alternative to r_layer)';


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
    color_scale integer NOT NULL,
    min double precision,
    max double precision,
    classes integer
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

ALTER TABLE ONLY data_models ALTER COLUMN id SET DEFAULT nextval('data_models_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY datasets ALTER COLUMN id SET DEFAULT nextval('datasets_id_seq'::regclass);


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

ALTER TABLE ONLY color_scales ALTER COLUMN id SET DEFAULT nextval('styles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ecosystem_components ALTER COLUMN id SET DEFAULT nextval('ecosystem_components_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impact_computation_methods ALTER COLUMN id SET DEFAULT nextval('impact_comp_method_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impact_layer2ecosystem_component ALTER COLUMN id SET DEFAULT nextval('impact_layer2ecosystem_component_id_seq'::regclass);


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

ALTER TABLE ONLY number_types ALTER COLUMN id SET DEFAULT nextval('number_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ops ALTER COLUMN id SET DEFAULT nextval('ops_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plan2dataset_extra ALTER COLUMN id SET DEFAULT nextval('plan2dataset_extra_id_seq'::regclass);


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

ALTER TABLE ONLY pressures ALTER COLUMN id SET DEFAULT nextval('activity2impact_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rule_classes ALTER COLUMN id SET DEFAULT nextval('rule_classes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rule_systems ALTER COLUMN id SET DEFAULT nextval('rule_systems_id_seq'::regclass);


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
-- Name: ImpactStrength_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impact_strengths
    ADD CONSTRAINT "ImpactStrength_pkey" PRIMARY KEY (id);


--
-- Name: activities_name_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY activities
    ADD CONSTRAINT activities_name_key UNIQUE (name);


--
-- Name: activities_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- Name: activity2impact_type_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY pressures
    ADD CONSTRAINT activity2impact_type_pkey PRIMARY KEY (id);


--
-- Name: activity2pressure_activity_pressure_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY pressures
    ADD CONSTRAINT activity2pressure_activity_pressure_key UNIQUE (activity, pressure_class);


--
-- Name: beliefs_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY beliefs
    ADD CONSTRAINT beliefs_pkey PRIMARY KEY (id);


--
-- Name: ecosystem_components_name_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ecosystem_components
    ADD CONSTRAINT ecosystem_components_name_key UNIQUE (name);


--
-- Name: ecosystem_components_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ecosystem_components
    ADD CONSTRAINT ecosystem_components_pkey PRIMARY KEY (id);


--
-- Name: impact_comp_method_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impact_computation_methods
    ADD CONSTRAINT impact_comp_method_pkey PRIMARY KEY (id);


--
-- Name: impact_layer2ecosystem_component_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impact_layer2ecosystem_component
    ADD CONSTRAINT impact_layer2ecosystem_component_pkey PRIMARY KEY (id);


--
-- Name: impact_layers_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impact_layers
    ADD CONSTRAINT impact_layers_pkey PRIMARY KEY (super);


--
-- Name: impacts_activity2pressure_ecosystem_component_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impacts
    ADD CONSTRAINT impacts_activity2pressure_ecosystem_component_key UNIQUE (pressure, ecosystem_component);


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

ALTER TABLE ONLY number_types
    ADD CONSTRAINT number_type_pkey PRIMARY KEY (id);


--
-- Name: number_types_name_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY number_types
    ADD CONSTRAINT number_types_name_key UNIQUE (name);


--
-- Name: ops_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ops
    ADD CONSTRAINT ops_pkey PRIMARY KEY (id);


--
-- Name: plan2dataset_extra_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plan2dataset_extra
    ADD CONSTRAINT plan2dataset_extra_pkey PRIMARY KEY (id);


--
-- Name: plan2dataset_extra_plan_dataset_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plan2dataset_extra
    ADD CONSTRAINT plan2dataset_extra_plan_dataset_key UNIQUE (plan, dataset);


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
-- Name: ranges_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ranges
    ADD CONSTRAINT ranges_pkey PRIMARY KEY (id);


--
-- Name: rule_classes_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rule_classes
    ADD CONSTRAINT rule_classes_pkey PRIMARY KEY (id);


--
-- Name: rule_systems_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rule_systems
    ADD CONSTRAINT rule_systems_pkey PRIMARY KEY (id);


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
-- Name: use_class2activity_use_class_activity_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use_class2activity
    ADD CONSTRAINT use_class2activity_use_class_activity_key UNIQUE (use_class, activity);


--
-- Name: use_classes_pkey; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use_classes
    ADD CONSTRAINT use_classes_pkey PRIMARY KEY (id);


--
-- Name: uses_plan_use_class_key; Type: CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY uses
    ADD CONSTRAINT uses_plan_use_class_key UNIQUE (plan, use_class);


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
-- Name: datasets_data_type_fkey; Type: FK CONSTRAINT; Schema: data; Owner: ajolma
--

ALTER TABLE ONLY datasets
    ADD CONSTRAINT datasets_data_type_fkey FOREIGN KEY (data_type) REFERENCES tool.number_types(id);


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

ALTER TABLE ONLY pressures
    ADD CONSTRAINT activity2impact_type_activity_fkey FOREIGN KEY (activity) REFERENCES activities(id);


--
-- Name: activity2impact_type_impact_type_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY pressures
    ADD CONSTRAINT activity2impact_type_impact_type_fkey FOREIGN KEY (pressure_class) REFERENCES pressure_classes(id);


--
-- Name: ecosystem_components_existence_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ecosystem_components
    ADD CONSTRAINT ecosystem_components_existence_fkey FOREIGN KEY (distribution) REFERENCES rule_systems(id);


--
-- Name: ecosystem_components_style_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY ecosystem_components
    ADD CONSTRAINT ecosystem_components_style_fkey FOREIGN KEY (style) REFERENCES styles(id);


--
-- Name: impact_layer2ecosystem_component_ecosystem_component_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impact_layer2ecosystem_component
    ADD CONSTRAINT impact_layer2ecosystem_component_ecosystem_component_fkey FOREIGN KEY (ecosystem_component) REFERENCES ecosystem_components(id);


--
-- Name: impact_layer2ecosystem_component_impact_layer_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impact_layer2ecosystem_component
    ADD CONSTRAINT impact_layer2ecosystem_component_impact_layer_fkey FOREIGN KEY (impact_layer) REFERENCES impact_layers(super);


--
-- Name: impact_layers_allocation_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impact_layers
    ADD CONSTRAINT impact_layers_allocation_fkey FOREIGN KEY (allocation) REFERENCES layers(id);


--
-- Name: impact_layers_comp_method_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impact_layers
    ADD CONSTRAINT impact_layers_comp_method_fkey FOREIGN KEY (computation_method) REFERENCES impact_computation_methods(id);


--
-- Name: impact_layers_id_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impact_layers
    ADD CONSTRAINT impact_layers_id_fkey FOREIGN KEY (super) REFERENCES layers(id);


--
-- Name: impacts_activity2impact_type_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impacts
    ADD CONSTRAINT impacts_activity2impact_type_fkey FOREIGN KEY (pressure) REFERENCES pressures(id);


--
-- Name: impacts_belief_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impacts
    ADD CONSTRAINT impacts_belief_fkey FOREIGN KEY (belief) REFERENCES beliefs(id);


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
-- Name: impacts_strength_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY impacts
    ADD CONSTRAINT impacts_strength_fkey FOREIGN KEY (strength) REFERENCES impact_strengths(id);


--
-- Name: layers_rules_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT layers_rules_fkey FOREIGN KEY (rule_system) REFERENCES rule_systems(id);


--
-- Name: layers_style2_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT layers_style2_fkey FOREIGN KEY (style) REFERENCES styles(id);


--
-- Name: plan2dataset_extra_dataset_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plan2dataset_extra
    ADD CONSTRAINT plan2dataset_extra_dataset_fkey FOREIGN KEY (dataset) REFERENCES data.datasets(id);


--
-- Name: plan2dataset_extra_plan_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY plan2dataset_extra
    ADD CONSTRAINT plan2dataset_extra_plan_fkey FOREIGN KEY (plan) REFERENCES plans(id);


--
-- Name: plan2use2layer_plan2use_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT plan2use2layer_plan2use_fkey FOREIGN KEY (use) REFERENCES uses(id);


--
-- Name: plan2use_plan_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY uses
    ADD CONSTRAINT plan2use_plan_fkey FOREIGN KEY (plan) REFERENCES plans(id);


--
-- Name: pressures_range_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY pressures
    ADD CONSTRAINT pressures_range_fkey FOREIGN KEY (range) REFERENCES ranges(id);


--
-- Name: rule_systems_rule_class_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rule_systems
    ADD CONSTRAINT rule_systems_rule_class_fkey FOREIGN KEY (rule_class) REFERENCES rule_classes(id);


--
-- Name: rules_r_dataset_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_r_dataset_fkey FOREIGN KEY (dataset) REFERENCES data.datasets(id);


--
-- Name: rules_r_layer_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_r_layer_fkey FOREIGN KEY (layer) REFERENCES layers(id);


--
-- Name: rules_r_op_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_r_op_fkey FOREIGN KEY (op) REFERENCES ops(id);


--
-- Name: rules_rule_system_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_rule_system_fkey FOREIGN KEY (rule_system) REFERENCES rule_systems(id);


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
-- Name: use2layer_layer_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY layers
    ADD CONSTRAINT use2layer_layer_fkey FOREIGN KEY (layer_class) REFERENCES layer_classes(id);


--
-- Name: use_class2activity_use_class_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY use_class2activity
    ADD CONSTRAINT use_class2activity_use_class_fkey FOREIGN KEY (use_class) REFERENCES use_classes(id);


--
-- Name: uses_use_class_fkey; Type: FK CONSTRAINT; Schema: tool; Owner: ajolma
--

ALTER TABLE ONLY uses
    ADD CONSTRAINT uses_use_class_fkey FOREIGN KEY (use_class) REFERENCES use_classes(id);


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
-- Name: data_models_id_seq; Type: ACL; Schema: data; Owner: ajolma
--

REVOKE ALL ON SEQUENCE data_models_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE data_models_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE data_models_id_seq TO ajolma;
GRANT ALL ON SEQUENCE data_models_id_seq TO smartsea;


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
-- Name: licenses_id_seq; Type: ACL; Schema: data; Owner: ajolma
--

REVOKE ALL ON SEQUENCE licenses_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE licenses_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE licenses_id_seq TO ajolma;
GRANT ALL ON SEQUENCE licenses_id_seq TO smartsea;


--
-- Name: organizations; Type: ACL; Schema: data; Owner: ajolma
--

REVOKE ALL ON TABLE organizations FROM PUBLIC;
REVOKE ALL ON TABLE organizations FROM ajolma;
GRANT ALL ON TABLE organizations TO ajolma;
GRANT ALL ON TABLE organizations TO smartsea;


--
-- Name: organizations_id_seq; Type: ACL; Schema: data; Owner: ajolma
--

REVOKE ALL ON SEQUENCE organizations_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE organizations_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE organizations_id_seq TO ajolma;
GRANT ALL ON SEQUENCE organizations_id_seq TO smartsea;


--
-- Name: units; Type: ACL; Schema: data; Owner: ajolma
--

REVOKE ALL ON TABLE units FROM PUBLIC;
REVOKE ALL ON TABLE units FROM ajolma;
GRANT ALL ON TABLE units TO ajolma;
GRANT ALL ON TABLE units TO smartsea;


--
-- Name: units_id_seq; Type: ACL; Schema: data; Owner: ajolma
--

REVOKE ALL ON SEQUENCE units_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE units_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE units_id_seq TO ajolma;
GRANT ALL ON SEQUENCE units_id_seq TO smartsea;


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
-- Name: pressures; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE pressures FROM PUBLIC;
REVOKE ALL ON TABLE pressures FROM ajolma;
GRANT ALL ON TABLE pressures TO ajolma;
GRANT ALL ON TABLE pressures TO smartsea;


--
-- Name: activity2impact_type_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE activity2impact_type_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE activity2impact_type_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE activity2impact_type_id_seq TO ajolma;
GRANT ALL ON SEQUENCE activity2impact_type_id_seq TO smartsea;


--
-- Name: beliefs; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE beliefs FROM PUBLIC;
REVOKE ALL ON TABLE beliefs FROM ajolma;
GRANT ALL ON TABLE beliefs TO ajolma;
GRANT ALL ON TABLE beliefs TO smartsea;


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
-- Name: ecosystem_components_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE ecosystem_components_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE ecosystem_components_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE ecosystem_components_id_seq TO ajolma;
GRANT ALL ON SEQUENCE ecosystem_components_id_seq TO smartsea;


--
-- Name: impact_computation_methods; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE impact_computation_methods FROM PUBLIC;
REVOKE ALL ON TABLE impact_computation_methods FROM ajolma;
GRANT ALL ON TABLE impact_computation_methods TO ajolma;
GRANT ALL ON TABLE impact_computation_methods TO smartsea;


--
-- Name: impact_comp_method_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE impact_comp_method_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE impact_comp_method_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE impact_comp_method_id_seq TO ajolma;
GRANT ALL ON SEQUENCE impact_comp_method_id_seq TO smartsea;


--
-- Name: impact_layer2ecosystem_component; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE impact_layer2ecosystem_component FROM PUBLIC;
REVOKE ALL ON TABLE impact_layer2ecosystem_component FROM ajolma;
GRANT ALL ON TABLE impact_layer2ecosystem_component TO ajolma;
GRANT ALL ON TABLE impact_layer2ecosystem_component TO smartsea;


--
-- Name: impact_layer2ecosystem_component_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE impact_layer2ecosystem_component_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE impact_layer2ecosystem_component_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE impact_layer2ecosystem_component_id_seq TO ajolma;
GRANT ALL ON SEQUENCE impact_layer2ecosystem_component_id_seq TO smartsea;


--
-- Name: impact_layers; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE impact_layers FROM PUBLIC;
REVOKE ALL ON TABLE impact_layers FROM ajolma;
GRANT ALL ON TABLE impact_layers TO ajolma;
GRANT ALL ON TABLE impact_layers TO smartsea;


--
-- Name: impact_strengths; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE impact_strengths FROM PUBLIC;
REVOKE ALL ON TABLE impact_strengths FROM ajolma;
GRANT ALL ON TABLE impact_strengths TO ajolma;
GRANT ALL ON TABLE impact_strengths TO smartsea;


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
GRANT ALL ON TABLE pressure_classes TO smartsea;


--
-- Name: impacts_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE impacts_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE impacts_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE impacts_id_seq TO ajolma;
GRANT ALL ON SEQUENCE impacts_id_seq TO smartsea;


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
GRANT ALL ON TABLE layer_classes TO smartsea;


--
-- Name: layers; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE layers FROM PUBLIC;
REVOKE ALL ON TABLE layers FROM ajolma;
GRANT ALL ON TABLE layers TO ajolma;
GRANT ALL ON TABLE layers TO smartsea;


--
-- Name: layers_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE layers_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE layers_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE layers_id_seq TO ajolma;
GRANT ALL ON SEQUENCE layers_id_seq TO smartsea;


--
-- Name: number_types; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE number_types FROM PUBLIC;
REVOKE ALL ON TABLE number_types FROM ajolma;
GRANT ALL ON TABLE number_types TO ajolma;
GRANT ALL ON TABLE number_types TO smartsea;


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
-- Name: ops_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE ops_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE ops_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE ops_id_seq TO ajolma;
GRANT ALL ON SEQUENCE ops_id_seq TO smartsea;


--
-- Name: plan2dataset_extra; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE plan2dataset_extra FROM PUBLIC;
REVOKE ALL ON TABLE plan2dataset_extra FROM ajolma;
GRANT ALL ON TABLE plan2dataset_extra TO ajolma;
GRANT ALL ON TABLE plan2dataset_extra TO smartsea;


--
-- Name: plan2dataset_extra_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE plan2dataset_extra_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE plan2dataset_extra_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE plan2dataset_extra_id_seq TO ajolma;
GRANT ALL ON SEQUENCE plan2dataset_extra_id_seq TO smartsea;


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
GRANT ALL ON TABLE pressure_categories TO smartsea;


--
-- Name: pressures_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE pressures_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE pressures_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE pressures_id_seq TO ajolma;
GRANT ALL ON SEQUENCE pressures_id_seq TO smartsea;


--
-- Name: ranges; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE ranges FROM PUBLIC;
REVOKE ALL ON TABLE ranges FROM ajolma;
GRANT ALL ON TABLE ranges TO ajolma;
GRANT ALL ON TABLE ranges TO smartsea;


--
-- Name: rule_classes; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE rule_classes FROM PUBLIC;
REVOKE ALL ON TABLE rule_classes FROM ajolma;
GRANT ALL ON TABLE rule_classes TO ajolma;
GRANT ALL ON TABLE rule_classes TO smartsea;


--
-- Name: rule_classes_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE rule_classes_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE rule_classes_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE rule_classes_id_seq TO ajolma;
GRANT ALL ON SEQUENCE rule_classes_id_seq TO smartsea;


--
-- Name: rule_systems; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON TABLE rule_systems FROM PUBLIC;
REVOKE ALL ON TABLE rule_systems FROM ajolma;
GRANT ALL ON TABLE rule_systems TO ajolma;
GRANT ALL ON TABLE rule_systems TO smartsea;


--
-- Name: rule_systems_id_seq; Type: ACL; Schema: tool; Owner: ajolma
--

REVOKE ALL ON SEQUENCE rule_systems_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE rule_systems_id_seq FROM ajolma;
GRANT ALL ON SEQUENCE rule_systems_id_seq TO ajolma;
GRANT ALL ON SEQUENCE rule_systems_id_seq TO smartsea;


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

