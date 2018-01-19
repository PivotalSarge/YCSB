/**
 * Copyright (c) 2013 - 2018 YCSB Contributors. All rights reserved.
 * <p>
 * Licensed under the Apache License, Version 2.0 (the "License"); you
 * may not use this file except in compliance with the License. You
 * may obtain a copy of the License at
 * <p>
 * http://www.apache.org/licenses/LICENSE-2.0
 * <p>
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * permissions and limitations under the License. See accompanying
 * LICENSE file.
 */

package com.yahoo.ycsb.db;

import com.yahoo.ycsb.ByteIterator;
import com.yahoo.ycsb.DB;
import com.yahoo.ycsb.DBException;
import com.yahoo.ycsb.Status;
import com.yahoo.ycsb.StringByteIterator;
import org.apache.geode.experimental.driver.Driver;
import org.apache.geode.experimental.driver.DriverFactory;
import org.apache.geode.experimental.driver.JSONWrapper;
import org.apache.geode.experimental.driver.Region;
import org.codehaus.jackson.JsonFactory;
import org.codehaus.jackson.JsonGenerator;
import org.codehaus.jackson.JsonParser;
import org.codehaus.jackson.JsonToken;
import org.codehaus.jackson.util.DefaultPrettyPrinter;

import java.io.IOException;
import java.io.StringReader;
import java.io.StringWriter;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import java.util.Set;
import java.util.Vector;

/**
 * Apache Geode client that uses the experimental driver for the YCSB benchmark.<br />
 * <p>Acts as a Geode client and tries to connect
 * to Geode cache server. A locator is used for discovering a cacheServer
 * by using the property <code>geode.locator=host[port]</code></p>
 */
public class GeodeProtobufClient extends DB {
  /**
   * property name to specify a Geode locator. This property can be used in both
   * client server and p2p topology
   */
  private static final String LOCATOR_PROPERTY_NAME = "geode.locator";

  /**
   * property name to specify Geode topology.
   */
  private static final String TOPOLOGY_PROPERTY_NAME = "geode.topology";

  /**
   * value of {@value #TOPOLOGY_PROPERTY_NAME} when peer to peer topology should be used.
   * (client-server topology is default)
   */
  private static final String TOPOLOGY_P2P_VALUE = "p2p";

  private Driver driver;

  @Override
  public void init() throws DBException {
    Properties properties = getProperties();
    if (properties != null && !properties.isEmpty()) {
      final String topology = properties.getProperty(TOPOLOGY_PROPERTY_NAME);
      if (topology != null && topology.equals(TOPOLOGY_P2P_VALUE)) {
        throw new DBException("Peer-to-peer topology is not supported");
      }

      String host = null;
      int port = -1;
      final String locatorValue = properties.getProperty(LOCATOR_PROPERTY_NAME);
      if (locatorValue != null) {
        final int index = locatorValue.indexOf('[');
        if (-1 != index) {
          host = locatorValue.substring(0, index);
          port = Integer.decode(locatorValue.substring(index + 1, locatorValue.length() - 1));
        }
      }
      if (host == null || port < 0) {
        throw new DBException("Locator is not configured");
      }

      try {
        System.out.println("host = " + host);
        System.out.println("port = " + port);
        driver = new DriverFactory().addLocator(host, port).create();
      } catch (Exception e) {
        throw new DBException("Unable to create driver", e);
      }
    }
  }

  @Override
  public Status read(String table, String key, Set<String> fields,
                     Map<String, ByteIterator> result) {
    try {
      JSONWrapper val = getRegion(table).get(key);
      if (val != null) {
        updateByteMap(result, val);
        return Status.OK;
      }
      return Status.ERROR;
    } catch (IOException e) {
      return Status.ERROR;
    }
  }

  @Override
  public Status scan(String table, String startkey, int recordcount,
                     Set<String> fields, Vector<HashMap<String, ByteIterator>> result) {
    // Geode does not support scan
    return Status.ERROR;
  }

  @Override
  public Status update(String table, String key, Map<String, ByteIterator> values) {
    try {
      getRegion(table).put(key, toJSONWrapper(values));
      return Status.OK;
    } catch (IOException e) {
      return Status.ERROR;
    }
  }

  @Override
  public Status insert(String table, String key, Map<String, ByteIterator> values) {
    try {
      getRegion(table).put(key, toJSONWrapper(values));
      return Status.OK;
    } catch (IOException e) {
      return Status.ERROR;
    }
  }

  @Override
  public Status delete(String table, String key) {
    try {
      getRegion(table).remove(key);
      return Status.OK;
    } catch (IOException e) {
      return Status.ERROR;
    }
  }

  private void updateByteMap(Map<String, ByteIterator> map, JSONWrapper jsonWrapper) {
    try {
      StringReader reader = new StringReader(jsonWrapper.getJSON());
      JsonParser parser = new JsonFactory().createJsonParser(reader);
      if (JsonToken.START_OBJECT == parser.nextToken()) {
        JsonToken token = parser.nextToken();
        while (JsonToken.END_OBJECT != token) {
          if (JsonToken.FIELD_NAME == token) {
            final String key = parser.getCurrentName();
            token = parser.nextToken();
            if (JsonToken.VALUE_STRING == token) {
              final String value = parser.getText();
              map.put(key, new StringByteIterator(value));
            }
          }
          token = parser.nextToken();
        }
      }
    } catch (IOException io) {
      // NOP
    }
  }

  private JSONWrapper toJSONWrapper(Map<String, ByteIterator> values) {
    try {
      StringWriter writer = new StringWriter();
      JsonGenerator generator = new JsonFactory().createJsonGenerator(writer);
      generator.setPrettyPrinter(new DefaultPrettyPrinter());
      generator.writeStartObject();
      for (Map.Entry<String, ByteIterator> entry : values.entrySet()) {
        generator.writeStringField(entry.getKey(), entry.getValue().toString());
      }
      generator.writeEndObject();
      generator.close();
      return JSONWrapper.wrapJSON(writer.toString());
    } catch (IOException ioe) {
      return JSONWrapper.wrapJSON("");
    }
  }

  private Region<String, JSONWrapper> getRegion(String table) {
    Region<String, JSONWrapper> r = driver.getRegion(table);
    return r;
  }
}
