<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:atom="http://www.w3.org/2005/Atom">
    <xsl:output method="html" version="1.0" encoding="UTF-8" indent="yes"/>
    <xsl:template match="/">
        <html xmlns="http://www.w3.org/1999/xhtml" lang="en">
            <head>
                <title>
                    <xsl:value-of select="/atom:feed/atom:title"/>
                </title>
                <link rel="stylesheet" href="/stylesheets/all.css"/>
            </head>
            <body class="home atom">
                <header class="top">
                    <nav>
                        <ul>
                            <li>
                                <a href="/">Go back</a>
                            </li>
                        </ul>
                    </nav>
                </header>

                <div class="row content">
                    <section>
                        <p class="note">
                            This is an Atom feed. Visit
                            <a href="https://aboutfeeds.com">About Feeds</a>
                            to learn more.
                        </p>

                        <header>
                            <h1>Articles</h1>
                        </header>

                        <table class="articles-index">
                            <tbody>
                                <xsl:for-each select="/atom:feed/atom:entry">
                                    <tr>
                                        <td>
                                            <time>
                                                <xsl:attribute name="datetime">
                                                    <xsl:value-of select="atom:published" />
                                                </xsl:attribute>
                                                <xsl:value-of select="atom:published" />
                                            </time>
                                        </td>
                                        <td>
                                            <a>
                                                <xsl:attribute name="href">
                                                    <xsl:value-of select="atom:link/@href"/>
                                                </xsl:attribute>
                                                <xsl:value-of select="atom:title"/>
                                            </a>
                                        </td>
                                    </tr>
                                </xsl:for-each>
                            </tbody>
                        </table>
                    </section>
                </div>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
